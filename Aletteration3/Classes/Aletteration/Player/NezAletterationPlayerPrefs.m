//
//  NezAletterationPlayerPrefs.m
//  Aletteration3
//
//  Created by David Nesbitt on 2013/11/11.
//  Copyright (c) 2013 David Nesbitt. All rights reserved.
//

#import "NezAletterationPlayerPrefs.h"
#import "NezRandom.h"

@implementation NezAletterationPlayerPrefs

-(instancetype)initWithCoder:(NSCoder *)coder {
	if ((self = [super init])) {
		[self decodeRestorableStateWithCoder:coder];
	}
	return self;
}

-(void)encodeWithCoder:(NSCoder *)coder {
	[self encodeRestorableStateWithCoder:coder];
}

-(instancetype)init {
	if ((self = [super init])) {
		_name = @"anonymous";
		_nickName = @"anonymous";
		_photo = [UIImage imageNamed:@"anonymous.png"];
		_color = GLKVector4Make(randomFloat(), randomFloat(), randomFloat(), 1.0);
		
		_soundsEnabled = YES;
		_soundsVolume = 0.5;
		_musicEnabled = YES;
		_musicVolume = 0.5;
		
		_undoConfirmation = YES;
		_undoCount = 10;
		
		_isLowercase = NO;
	}
	return self;
}

-(void)encodeRestorableStateWithCoder:(NSCoder*)coder {
	NSData *photoData = UIImagePNGRepresentation(_photo);
	[coder encodeObject:photoData forKey:@"photoData"];

	[coder encodeObject:_name forKey:@"_name"];
	[coder encodeObject:_nickName forKey:@"_nickName"];
	
	[coder encodeFloat:_color.r forKey:@"_color.r"];
	[coder encodeFloat:_color.g forKey:@"_color.g"];
	[coder encodeFloat:_color.b forKey:@"_color.b"];
	[coder encodeFloat:_color.a forKey:@"_color.a"];

	[coder encodeBool:_soundsEnabled forKey:@"_soundsEnabled"];
	[coder encodeFloat:_soundsVolume forKey:@"_soundsVolume"];
	[coder encodeBool:_musicEnabled forKey:@"_musicEnabled"];
	[coder encodeFloat:_musicVolume forKey:@"_musicVolume"];

	[coder encodeBool:_undoConfirmation forKey:@"_undoConfirmation"];
	[coder encodeInteger:_undoCount forKey:@"_undoCount"];

	[coder encodeBool:_isLowercase forKey:@"_isLowercase"];
}

-(void)decodeRestorableStateWithCoder:(NSCoder*)coder {
	NSData *photoData = [coder decodeObjectForKey:@"photoData"];
	_photo = [UIImage imageWithData:photoData];

	_name = [coder decodeObjectForKey:@"_name"];
	_nickName = [coder decodeObjectForKey:@"_nickName"];
	
	_color.r = [coder decodeFloatForKey:@"_color.r"];
	_color.g = [coder decodeFloatForKey:@"_color.g"];
	_color.b = [coder decodeFloatForKey:@"_color.b"];
	_color.a = [coder decodeFloatForKey:@"_color.a"];

	_soundsEnabled = [coder decodeBoolForKey:@"_soundsEnabled"];
	_soundsVolume = [coder decodeFloatForKey:@"_soundsVolume"];
	_musicEnabled = [coder decodeBoolForKey:@"_musicEnabled"];
	_musicVolume = [coder decodeFloatForKey:@"_musicVolume"];

	_undoConfirmation = [coder decodeBoolForKey:@"_undoConfirmation"];
	_undoCount = [coder decodeIntegerForKey:@"_undoCount"];

	_isLowercase = [coder decodeBoolForKey:@"_isLowercase"];
}

@end
