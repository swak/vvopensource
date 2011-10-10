//
//  AppController.m
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"




#define NSNULL [NSNull null]
#define MAXMSGS 25




@implementation AppController


+ (void) load	{
	//	the OSCAddressSpace automatically creates a single instance of itself when the class is initialized (as soon as you call anything that uses the OSCAddressSpace class, it gets created)
	[OSCAddressSpace class];
}
- (id) init	{
	if (self = [super init])	{
		myChain = nil;
		targetChain = nil;
		rxMsgs = [[MutLockArray alloc] init];
		txMsgs = [[MutLockArray alloc] init];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) awakeFromNib	{
	[_mainAddressSpace setDelegate:self];
	[_mainAddressSpace setAutoQueryReply:YES];
	[_mainAddressSpace setQueryDelegate:self];
	[oscManager setDelegate:self];
}


- (IBAction) createMenuItemChosen:(id)sender	{
	//NSLog(@"%s ... %@",__func__,sender);
	NSString		*title = [sender title];
	if (title == nil)
		return;
	ElementBox		*newBox = [[ElementBox alloc] initWithFrame:NSMakeRect(0,0,300,80)];
	if (newBox == nil)
		return;
	
	if ([title isEqualToString:@"Button (Boolean)"])
		[newBox setType:OSCValBool andName:[NSString stringWithFormat:@"Item %d",[myChain count]+1]];
	else if ([title isEqualToString:@"Slider (Float)"])
		[newBox setType:OSCValFloat andName:[NSString stringWithFormat:@"Item %d",[myChain count]+1]];
	else if ([title isEqualToString:@"Text Field (String)"])
		[newBox setType:OSCValString andName:[NSString stringWithFormat:@"Item %d",[myChain count]+1]];
	
	[myChain addElement:newBox];
	[newBox release];
}
- (IBAction) clearButtonUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	[myChain clearAllElements];
}


- (IBAction) populateButtonUsed:(id)sender	{

}

- (IBAction) listNodesClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeNamespaceExploration forAddress:address];
	
	[self addTXMsg:msg];
	
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutput:manualOutput];
}
- (IBAction) documentationClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeDocumentation forAddress:address];
	
	[self addTXMsg:msg];
	[oscManager dispatchQuery:msg toOutput:manualOutput];
}
- (IBAction) acceptedTypesClicked:(id)sender	{
	NSLog(@"%s",__func__);
}
- (IBAction) currentValClicked:(id)sender	{
	NSLog(@"%s",__func__);
}


- (IBAction) clearDataViewsClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	[txMsgs wrlock];
	[rxMsgs wrlock];
	
	[txMsgs removeAllObjects];
	[rxMsgs removeAllObjects];
	[self _lockedUpdateDataAndViews];
	
	[txMsgs unlock];
	[rxMsgs unlock];
}


- (void) addTXMsg:(OSCMessage *)m	{
	if (m==nil)
		return;
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:NSNULL];
		[txMsgs addObject:m];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
}
- (void) addRXMsg:(OSCMessage *)m	{
	if (m==nil)
		return;
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:m];
		[txMsgs addObject:NSNULL];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
}


- (void) _lockedUpdateDataAndViews	{
	while ([rxMsgs count] > MAXMSGS)
		[rxMsgs removeObjectAtIndex:0];
	while ([txMsgs count] > MAXMSGS)
		[txMsgs removeObjectAtIndex:0];
	
	NSMutableString		*rxString = [NSMutableString stringWithCapacity:0];
	NSMutableString		*txString = [NSMutableString stringWithCapacity:0];
	int					lineCount = 0;
	
	for (OSCMessage *tmpMsg in [rxMsgs array])	{
		if ((NSNull *)tmpMsg == NSNULL)
			[rxString appendFormat:@"%d\n",lineCount];
		else
			[rxString appendFormat:@"%d\t%@\n",lineCount,[tmpMsg description]];
		++lineCount;
	}
	[rxDataView
		performSelectorOnMainThread:@selector(setString:)
		withObject:[[rxString copy] autorelease]
		waitUntilDone:NO];
	
	lineCount = 0;
	for (OSCMessage *tmpMsg in [txMsgs array])	{
		if ((NSNull *)tmpMsg == NSNULL)
			[txString appendFormat:@"%d\n",lineCount];
		else
			[txString appendFormat:@"%d\t%@\n",lineCount,[tmpMsg description]];
		++lineCount;
	}
	[txDataView
		performSelectorOnMainThread:@selector(setString:)
		withObject:[[txString copy] autorelease]
		waitUntilDone:NO];
}


/*===================================================================================*/
#pragma mark --------------------- OSCManager delegate (OSCDelegateProtocol)
/*------------------------------------*/


- (void) receivedOSCMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	[self addRXMsg:m];
	
	OSCMessageType		mType = [m messageType];
	switch (mType)	{
		case OSCMessageTypeReply:
		case OSCMessageTypeError:
			NSLog(@"\t\t%s received reply/error: %@",__func__,m);
			break;
		default:
			[_mainAddressSpace dispatchMessage:m];
			break;
	}
}


/*===================================================================================*/
#pragma mark --------------------- OSCNodeQueryDelegateProtocol- i'm the OSCAddressSpace's query delegate
/*------------------------------------*/


- (NSMutableArray *) namespaceArrayForNode:(OSCNode *)n	{
	return nil;
}
- (NSString *) docStringForNode:(OSCNode *)n	{
	//NSLog(@"%s",__func__);
	return nil;
}
- (NSString *) typeSignatureForNode:(OSCNode *)n	{
	return nil;
}
- (OSCValue *) currentValueForNode:(OSCNode *)n	{
	return nil;
}
- (NSString *) returnTypeStringForNode:(OSCNode *)n	{
	return nil;
}


/*===================================================================================*/
#pragma mark --------------------- OSCAddressSpaceDelegateProtocol- i'm the OSCAddressSpace's delegate
/*------------------------------------*/


- (void) nodeRenamed:(OSCNode *)n	{
	/*		left intentionally blank- don't need to do anything, just want to avoid a warning for not having this method		*/
}
- (void) dispatchReplyOrError:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	[self addTXMsg:m];
	
	[oscManager dispatchReplyOrError:m];
}


@end
