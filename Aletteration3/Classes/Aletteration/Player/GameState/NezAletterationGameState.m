//
//  NezAletterationGameState.m
//  Aletteration3
//
//  Created by David Nesbitt on 2013-09-30.
//  Copyright (c) 2013 David Nesbitt. All rights reserved.
//

#import "NezRandom.h"
#import "NezAletterationSQLiteDictionary.h"
#import "NezAletterationGameState.h"
#import "NezAletterationGameStateTurn.h"
#import "NezAletterationGameStateLineState.h"
#import "NezAletterationGameStateRetiredWord.h"
#import "NezAletterationGameStateLineStateStack.h"

static NezAletterationLetterBag gLetterBag = {
	5, 2, 4, 4, 10, 2, 3, 4, 5, 1, 2, 4, 3,
	5, 5, 3, 1, 5,  5, 5, 4, 2, 2, 1, 2, 1,
};

static NezAletterationLetterBag gEmptyBag = {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

static int gLetterCount;

@interface NezAletterationGameState() {
	NSMutableData *_lineData;
	NSMutableData *_letterData;
	NSMutableArray *_turnStack;
	NSMutableArray *_lineStateList;
	
	NSMutableData *_currentLetterBagData;
	
	char *_lines[NEZ_ALETTERATION_LINE_COUNT];
}

@property (readonly, getter = getCurrentLetterBagPtr) NezAletterationLetterBag *currentLetterBagPtr;
@property (readonly, getter = getCurrentLetterBagCopy) NezAletterationLetterBag currentLetterBagCopy;

@end

@implementation NezAletterationGameState

+(void)initialize {
	@synchronized (self) {
		static BOOL initialized = NO;
		if(!initialized) {
			initialized = YES;
			for (int i=0; i<NEZ_ALETTERATION_ALPHABET_COUNT;i++) {
				gLetterCount += gLetterBag.count[i];
			}
		}
	}
}

+(NezAletterationLetterBag)fullLetterBag {
	return gLetterBag;
}

+(int)letterCount {
	return gLetterCount;
}

-(instancetype)init {
	if ((self = [super init])) {
		int longestStringLength = [NezAletterationGameState letterCount]+1;
		_lineData = [NSMutableData dataWithLength:longestStringLength*NEZ_ALETTERATION_LINE_COUNT];
		_letterData = [NSMutableData dataWithLength:longestStringLength];
		[self randomizeLetterList];
		_turnStack = [NSMutableArray array];
		_lineStateList = [NSMutableArray array];
		for (int i=0; i<NEZ_ALETTERATION_LINE_COUNT;i++) {
			[_lineStateList addObject:[[NezAletterationGameStateLineStateStack alloc] init]];
			_lines[i] = (char*)_lineData.bytes+(i*longestStringLength);
		}
		_currentLetterBagData = [NSMutableData dataWithBytes:&gLetterBag length:sizeof(NezAletterationLetterBag)];
		NSLog(@"%@", self);
	}
	return self;
}

-(id)initWithCoder:(NSCoder*)decoder {
	if ((self = [super init])) {
		int longestStringLength = [NezAletterationGameState letterCount]+1;
		_lineData = [decoder decodeObjectForKey:@"_lineData"];
		_letterData = [decoder decodeObjectForKey:@"_letterData"];
		_turnStack = [decoder decodeObjectForKey:@"_turnStack"];
		_lineStateList = [decoder decodeObjectForKey:@"_lineStateList"];
		for (int i=0; i<NEZ_ALETTERATION_LINE_COUNT;i++) {
			_lines[i] = (char*)_lineData.bytes+(i*longestStringLength);
		}
		_currentLetterBagData = [decoder decodeObjectForKey:@"_currentLetterBagData"];
		NSLog(@"%@", self);
	}
	return self;
}

-(void)encodeWithCoder:(NSCoder*)encoder {
	[encoder encodeObject:_lineData forKey:@"_lineData"];
	[encoder encodeObject:_letterData forKey:@"_letterData"];
	[encoder encodeObject:_turnStack forKey:@"_turnStack"];
	[encoder encodeObject:_lineStateList forKey:@"_lineStateList"];
	[encoder encodeObject:_currentLetterBagData forKey:@"_currentLetterBagData"];
}

-(NezAletterationLetterBag*)getCurrentLetterBagPtr {
	return (NezAletterationLetterBag*)_currentLetterBagData.bytes;
}

-(NezAletterationLetterBag)getCurrentLetterBagCopy {
	NezAletterationLetterBag letterBag = *self.currentLetterBagPtr;
	if (self.currentStateTurn.lineIndex == -1) {
		char currentLetter = self.currentLetter;
		if (currentLetter >= 'a' && currentLetter <= 'z') {
			letterBag.count[currentLetter-'a']++;
		} else {
			//If this happens then the letterbag should be completely empty. currentLetter can equal '\0'.
			return gEmptyBag;
		}
	}
	return letterBag;
}

-(char*)getLetterList {
	return (char*)_letterData.bytes;
}

-(void)copyLetterListIntoArray:(char*)dstLetterList {
	char *srcLetterList = self.letterList;
	memcpy(dstLetterList, srcLetterList, _letterData.length);
}

-(void)useLetterList:(char*)srcLetterList {
	memcpy(self.letterList, srcLetterList, _letterData.length);
}

-(char)getCurrentLetter {
	if (_turnStack.count == 0 || self.turn > gLetterCount) {
		return '\0';
	} else {
		char letter = self.letterList[self.turn-1];
		if (letter < 'a' || letter > 'z') {
			//This should never happen. It means the letter data is corrupt such as after a state restoration.
			[NSException raise:@"Letter Data is invalid" format:@"Invalid Letter Data object %@", _letterData];
			return '\0';
		}
		return letter;
	}
}

-(char)getCurrentLetterIndex {
	return self.currentLetter-'a';
}

-(char)letterForTurn:(NSInteger)turnIndex {
	return self.letterList[turnIndex];
}

-(void)randomizeLetterList {
	NSMutableArray *orderedLetterList = [NSMutableArray arrayWithCapacity:[NezAletterationGameState letterCount]];
	NezAletterationLetterBag letterBag = gLetterBag;
	for (char i=0; i<NEZ_ALETTERATION_ALPHABET_COUNT;i++) {
		for (char j=0; j<letterBag.count[i]; j++) {
			[orderedLetterList addObject:[NSNumber numberWithChar:'a'+i]];
		}
	}
	int index = 0;
	char letter = '\0', previousLetter = '\0';
	int lettersRemaining = NEZ_ALETTERATION_ALPHABET_COUNT;
	char *letterList = self.letterList;
	while (orderedLetterList.count > 0) {
		int randomIndex = randomFloatInRange(0, orderedLetterList.count);
		letter = [orderedLetterList[randomIndex] charValue];
		if (letter != previousLetter || lettersRemaining == 1) {
			letterBag.count[letter-'a']--;
			if (letterBag.count[letter-'a'] == 0) {
				lettersRemaining--;
			}
			letterList[index++] = [orderedLetterList[randomIndex] charValue];
			[orderedLetterList removeObjectAtIndex:randomIndex];
			previousLetter = letter;
		}
	}
	letterList[index] = '\0';
	
	strcpy(letterList, "quizwlrotngerkenishabeoearhtsigdaoueyvrptrwcudafxvtkemueytolcndmaheclmelcsifibsnhnepgodpjs");
	
	NSLog(@"%s", letterList);
}

-(NSInteger)getTurn {
	return _turnStack.count;
}

-(NSInteger)getPreviousTurn {
	return _turnStack.count-1;
}

-(NezAletterationGameStateTurn*)getCurrentStateTurn {
	return _turnStack.lastObject;
}

-(NezAletterationGameStateTurn*)getPreviousStateTurn {
	if (_turnStack.count > 1) {
		return _turnStack[_turnStack.count-2];
	} else {
		return nil;
	}
}

-(NSArray*)turnsInRange:(NSRange)range {
	return [_turnStack subarrayWithRange:range];
}

-(NezAletterationGameStateLineStateStack*)stateStackForIndex:(NSInteger)index {
	return _lineStateList[index];
}

-(BOOL)startTurn {
	[_turnStack addObject:[NezAletterationGameStateTurn turn]];
	if (self.turn > gLetterCount) {//<-------------------------------------------------+
		return NO;                                                    //                |
	} else {                                                         //                |
		char currentLetter = self.currentLetter;                      //                |
		if (currentLetter >= 'a' && currentLetter <= 'z') {           //                |
			self.currentLetterBagPtr->count[self.currentLetterIndex]--;//                |
		} else {//                                                                      |
			//This should never happen because I just checked to see if turn was at the end.
			return NO;
		}
		return YES;
	}
}

-(void)endTurn {
	NezAletterationGameStateTurn *stateTurn = self.currentStateTurn;
	stateTurn.lineIndex = stateTurn.temporaryLineIndex;
	NezAletterationGameStateLineStateStack *lineStateStack = [self stateStackForIndex:stateTurn.lineIndex];
	
	_lines[stateTurn.lineIndex][lineStateStack.count] = self.currentLetter;
	
	[self pushNextLineState:lineStateStack];
	for (NSInteger i=0; i<NEZ_ALETTERATION_LINE_COUNT; i++) {
		[self updateStateForLine:i];
	}
}

-(void)endTurnWithLineIndex:(NSInteger)lineIndex andUpdatedLineStateList:(NSArray*)updatedLineStateList {
	NezAletterationGameStateTurn *stateTurn = self.currentStateTurn;
	stateTurn.lineIndex = lineIndex;
	NezAletterationGameStateLineStateStack *lineStateStack = [self stateStackForIndex:lineIndex];
	
	_lines[lineIndex][lineStateStack.count] = self.currentLetter;
	
	[self pushNextLineState:lineStateStack];
	
	[updatedLineStateList enumerateObjectsUsingBlock:^(NezAletterationGameStateLineState *updatedLineState, NSUInteger idx, BOOL *stop) {
		[self updateStateForLine:idx andUpdatedLineState:updatedLineState];
	}];
}

-(void)undoTurn {
	char currentLetter = self.currentLetter;
	if (currentLetter >= 'a' && currentLetter <= 'z') {
		self.currentLetterBagPtr->count[self.currentLetterIndex]++;
	} else {
		//TODO:ERROR this should never happen
		return;
	}
	NezAletterationGameStateTurn *turn = self.currentStateTurn;
	[_turnStack removeLastObject];
	[turn.retiredWordList enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NezAletterationGameStateRetiredWord *retiredWord, NSUInteger idx, BOOL *stop) {
		NezAletterationGameStateLineStateStack *stateStack = [self stateStackForIndex:retiredWord.lineIndex];
		[stateStack pushLineStateList:retiredWord.stateList];
		[self fillLine:_lines[retiredWord.lineIndex] withStateStack:stateStack];
	}];

	turn = self.currentStateTurn;
	turn.temporaryLineIndex = -1;
	turn.lineIndex = -1;
	
	for (NSInteger i=0; i<NEZ_ALETTERATION_LINE_COUNT; i++) {
		[[self stateStackForIndex:i] removeLineStatesForTurn:self.turn];
	}
}

-(void)fillLine:(char*)line withStateStack:(NezAletterationGameStateLineStateStack*)stateStack {
	NSArray *stateList = stateStack.stateList;
	NezAletterationGameStateLineState *state = stateStack.topLineState;
	for (int i=state.index, n=state.index+state.length; i<n; i++) {
		NezAletterationGameStateLineState *state = stateList[i];
		line[i] = self.letterList[state.turn-1];
	}
	line[stateList.count] = '\0';
}

-(void)updateStateForLine:(NSInteger)lineIndex {
	NezAletterationGameStateLineStateStack *lineStateStack = [self stateStackForIndex:lineIndex];
	_lines[lineIndex][lineStateStack.count] = '\0';
	NezAletterationGameStateLineState *currentState = lineStateStack.topLineState;
	NezAletterationGameStateLineState *updatedState = [self updatedState:currentState forLine:_lines[lineIndex]];
	if (updatedState && ![currentState isEqual:updatedState]) {
		NSLog(@"%@ - [%s]", updatedState, _lines[lineIndex]);
		[lineStateStack pushUpdatedState:updatedState];
	}
}

-(void)updateStateForLine:(NSInteger)lineIndex andUpdatedLineState:(NezAletterationGameStateLineState*)updatedState {
	if (updatedState && updatedState.state != -1 && updatedState.turn == self.turn) {
		NezAletterationGameStateLineStateStack *lineStateStack = [self stateStackForIndex:lineIndex];
		_lines[lineIndex][lineStateStack.count] = '\0';
		NezAletterationGameStateLineState *currentState = lineStateStack.topLineState;
		if (![currentState isEqual:updatedState]) {
			[lineStateStack pushUpdatedState:updatedState];
		}
	}
}

-(NezAletterationGameStateLineState*)updatedState:(NezAletterationGameStateLineState*)state forLine:(char*)line {
	if (state) {
		NezAletterationGameStateLineState *lineState = [NezAletterationGameStateLineState lineStateCopy:state];
		if (lineState.state == NEZ_DIC_INPUT_ISNOT_SET || lineState.state == NEZ_DIC_INPUT_ISPREFIX) {
			lineState.state = [NezAletterationSQLiteDictionary getTypeWithInput:line+lineState.index LetterCounts:self.currentLetterBagCopy];
			while (lineState.state == NEZ_DIC_INPUT_ISNOTHING && lineState.length > 1) {
				lineState.length--;
				lineState.index++;
				lineState.state = [NezAletterationSQLiteDictionary getTypeWithInput:line+lineState.index LetterCounts:self.currentLetterBagCopy];
			}
		}
		lineState.turn = self.turn;
		return lineState;
	}
	return nil;
}

-(void)pushNextLineState:(NezAletterationGameStateLineStateStack*)lineStateStack {
	NezAletterationGameStateLineState *currentLineState = lineStateStack.topLineState;
	NezAletterationGameStateLineState *nextLineState = [NezAletterationGameStateLineState nextLineState:currentLineState];
	nextLineState.turn = self.turn;
	[lineStateStack pushLineState:nextLineState];
}

-(NezAletterationGameStateLineState*)currentLineStateForIndex:(NSInteger)index {
	NezAletterationGameStateLineStateStack *lineStateStack = [self stateStackForIndex:index];
	NezAletterationGameStateLineState *lineState = [NezAletterationGameStateLineState lineStateCopy:lineStateStack.topLineState];
	return lineState;
}

-(NezAletterationGameStateRetiredWord*)retireWordFromLine:(NSInteger)lineIndex {
	NezAletterationGameStateLineStateStack *lineStateStack = [self stateStackForIndex:lineIndex];
	NezAletterationGameStateLineState *lineState = lineStateStack.topLineState;
	NezAletterationGameStateRetiredWord *retiredWord = [[NezAletterationGameStateRetiredWord alloc] init];
	retiredWord.lineIndex = lineIndex;
	retiredWord.range = NSMakeRange(lineState.index, lineState.length);
	retiredWord.stateList = [lineStateStack removeStatesInRange:retiredWord.range];
	[self.currentStateTurn.retiredWordList addObject:retiredWord];
	[self updateStateForLine:lineIndex];
	return retiredWord;
}

-(NSString*)description {
	NSString *description = [NSString stringWithFormat:@"NezAletterationGameState {\n\t%s\n\n\tTurns:\n", self.letterList];
	for (NezAletterationGameStateTurn *turn in _turnStack) {
		description = [NSString stringWithFormat:@"%@\t\t%@\n", description, turn];
	}
	description = [NSString stringWithFormat:@"%@}", description];
	return description;
}

@end
