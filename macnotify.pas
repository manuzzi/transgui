{*************************************************************************************
  This file is part of Transmission Remote GUI.
  Copyright (c) 2008-2019 by Yury Sidorov and Transmission Remote GUI working group.

  Transmission Remote GUI is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  Transmission Remote GUI is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Transmission Remote GUI; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301, USA.

  In addition, as a special exception, the copyright holders give permission to
  link the code of portions of this program with the OpenSSL library under
  certain conditions as described in each individual source file, and distribute
  linked combinations including the two.

  You must obey the GNU General Public License in all respects for all of the
  code used other than OpenSSL.  If you modify file(s) with this exception, you
  may extend this exception to your version of the file(s), but you are not
  obligated to do so.  If you do not wish to do so, delete this exception
  statement from your version.  If you delete this exception statement from all
  source files in the program, then also delete it in the issue.
*************************************************************************************}

{ Native macOS notifications through the UserNotifications framework.

  The framework is not part of the Free Pascal Cocoa headers, so the few classes
  that are needed are declared here. Notifications require the application to run
  from a code signed bundle with a bundle identifier; outside of a bundle the
  functions of this unit do nothing. }

unit macnotify;

{$mode objfpc}{$H+}
{$modeswitch objectivec1}
{$modeswitch cblocks}

{$linkframework UserNotifications}

interface

{ True when the process runs from an application bundle and can use the
  user notification center. }
function NotificationsSupported: boolean;

{ Registers the notification center delegate that lets banners appear while the
  application is active. Call it once, early at startup. }
procedure InitNotifications;

{ Asks macOS for permission to show notifications. The system dialog is shown
  only the first time. Later calls return silently and the choice of the user
  can be changed in System Settings. }
procedure RequestNotificationAuthorization;

{ Delivers a notification right away. Nothing is shown when the user did not
  allow notifications for the application. }
procedure PostNotification(const Title, Text: string);

implementation

uses
  CocoaAll;

const
  UNAuthorizationOptionBadge = 1 shl 0;
  UNAuthorizationOptionSound = 1 shl 1;
  UNAuthorizationOptionAlert = 1 shl 2;

  UNNotificationPresentationOptionSound = 1 shl 1;
  UNNotificationPresentationOptionList = 1 shl 3;
  UNNotificationPresentationOptionBanner = 1 shl 4;

type
  UNNotificationSound = objcclass external (NSObject)
  public
    class function defaultSound: UNNotificationSound; message 'defaultSound';
  end;

  UNNotificationContent = objcclass external (NSObject)
  end;

  UNMutableNotificationContent = objcclass external (UNNotificationContent)
  public
    procedure setTitle(newValue: NSString); message 'setTitle:';
    procedure setBody(newValue: NSString); message 'setBody:';
    procedure setSound(newValue: UNNotificationSound); message 'setSound:';
  end;

  UNNotificationTrigger = objcclass external (NSObject)
  end;

  UNNotification = objcclass external (NSObject)
  end;

  UNNotificationRequest = objcclass external (NSObject)
  public
    class function requestWithIdentifier_content_trigger(identifier: NSString;
      content: UNNotificationContent; trigger: UNNotificationTrigger): UNNotificationRequest;
      message 'requestWithIdentifier:content:trigger:';
  end;

  TAuthorizationHandler = reference to procedure(granted: ObjCBool; error: NSError); cblock; cdecl;
  TAddRequestHandler = reference to procedure(error: NSError); cblock; cdecl;
  TPresentationHandler = reference to procedure(options: NSUInteger); cblock; cdecl;

  UNUserNotificationCenter = objcclass external (NSObject)
  public
    class function currentNotificationCenter: UNUserNotificationCenter;
      message 'currentNotificationCenter';
    procedure setDelegate(newValue: id); message 'setDelegate:';
    procedure requestAuthorizationWithOptions_completionHandler(options: NSUInteger;
      completionHandler: TAuthorizationHandler);
      message 'requestAuthorizationWithOptions:completionHandler:';
    procedure addNotificationRequest_withCompletionHandler(request: UNNotificationRequest;
      completionHandler: TAddRequestHandler);
      message 'addNotificationRequest:withCompletionHandler:';
  end;

  { Lets macOS show the banner also when Transmission Remote GUI is the active
    application. Without a delegate such notifications are dropped silently. }
  TNotificationDelegate = objcclass(NSObject)
  public
    procedure userNotificationCenter_willPresentNotification_withCompletionHandler(
      center: UNUserNotificationCenter; notification: UNNotification;
      completionHandler: TPresentationHandler);
      message 'userNotificationCenter:willPresentNotification:withCompletionHandler:';
  end;

var
  Delegate: TNotificationDelegate = nil;

{ The handlers below are called by the system on threads that are not managed by
  Free Pascal, so they must stay trivial: no strings, no exceptions. }

procedure TNotificationDelegate.userNotificationCenter_willPresentNotification_withCompletionHandler(
  center: UNUserNotificationCenter; notification: UNNotification;
  completionHandler: TPresentationHandler);
begin
  completionHandler(UNNotificationPresentationOptionBanner or
    UNNotificationPresentationOptionList or UNNotificationPresentationOptionSound);
end;

procedure AuthorizationDone(granted: ObjCBool; error: NSError); cdecl;
begin
end;

procedure RequestDone(error: NSError); cdecl;
begin
end;

function NotificationsSupported: boolean;
var
  Bundle: NSBundle;
begin
  { UNUserNotificationCenter raises an Objective-C exception when the process is
    not an application bundle (for example the bare binary during development). }
  Bundle:=NSBundle.mainBundle;
  Result:=(Bundle <> nil) and (Bundle.bundleIdentifier <> nil) and
          Bundle.bundlePath.hasSuffix(NSSTR('.app'));
end;

procedure InitNotifications;
begin
  if (Delegate <> nil) or not NotificationsSupported then
    exit;
  Delegate:=TNotificationDelegate.alloc.init;
  UNUserNotificationCenter.currentNotificationCenter.setDelegate(Delegate);
end;

procedure RequestNotificationAuthorization;
begin
  if not NotificationsSupported then
    exit;
  UNUserNotificationCenter.currentNotificationCenter.requestAuthorizationWithOptions_completionHandler(
    UNAuthorizationOptionAlert or UNAuthorizationOptionSound, @AuthorizationDone);
end;

procedure PostNotification(const Title, Text: string);
var
  Content: UNMutableNotificationContent;
  Request: UNNotificationRequest;
begin
  if not NotificationsSupported then
    exit;
  Content:=UNMutableNotificationContent.alloc.init;
  try
    Content.setTitle(NSString.stringWithUTF8String(PAnsiChar(Title)));
    Content.setBody(NSString.stringWithUTF8String(PAnsiChar(Text)));
    Content.setSound(UNNotificationSound.defaultSound);
    { Every notification gets its own identifier. A repeated identifier would replace
      the notification that is already delivered. }
    Request:=UNNotificationRequest.requestWithIdentifier_content_trigger(
      NSUUID.UUID.UUIDString, Content, nil);
    UNUserNotificationCenter.currentNotificationCenter.addNotificationRequest_withCompletionHandler(
      Request, @RequestDone);
  finally
    Content.release;
  end;
end;

end.
