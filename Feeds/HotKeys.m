//#import "HotKeys.h"
//
//NSString *kHotKeyManagerOpenMenuNotification = @"HotKeyManagerOpenMenuNotification";
//
//OSStatus HotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData);
//
//@implementation HotKeys
//
//+ (void)registerHotKeys
//{
//	// hotkey event type
//	EventTypeSpec eventType;
//	eventType.eventClass=kEventClassKeyboard;
//	eventType.eventKind=kEventHotKeyPressed;
//
//	// our handle (I think)
//	EventHotKeyRef gHotKeyRef;
//
//	// sign up for hotkey events
//	InstallApplicationEventHandler(&HotKeyHandler,1,&eventType,NULL,NULL);
//
//	// first hotkey
//	EventHotKeyID openMenuID;
//	openMenuID.signature='htk1';
//	openMenuID.id=1;
//	
//	// "s" == 1
//	RegisterEventHotKey(1, controlKey+optionKey, openMenuID, 
//						GetApplicationEventTarget(), 0, &gHotKeyRef);
//	
//	// hotkey to quit
//	EventHotKeyID quitID;
//	quitID.signature='htk2';
//	quitID.id=2;
//	
//	// "0" == 29
//	RegisterEventHotKey(29, controlKey+optionKey, quitID, 
//						GetApplicationEventTarget(), 0, &gHotKeyRef);	
//}
//
//OSStatus HotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent,
//						 void *userData)
//{
//	EventHotKeyID hkCom;
//	GetEventParameter(theEvent,kEventParamDirectObject,typeEventHotKeyID,NULL,
//					  sizeof(hkCom),NULL,&hkCom);
//	int l = hkCom.id;
//	
//	switch (l) {
//		case 1: // send finder items
//			[[NSNotificationCenter defaultCenter] postNotificationName:kHotKeyManagerOpenMenuNotification object:nil];
//			break;
//		case 2: // quit (convenience for developing)
//			[[NSApplication sharedApplication] terminate:nil];
//			break;
//	}
//	return noErr;
//}
//
//@end
