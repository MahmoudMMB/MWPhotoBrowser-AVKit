/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "MWAnimatedImagePlayer.h"
#import "NSImage+Compatibility.h"
#import "MWDisplayLink.h"
#import "MWDeviceHelper.h"
#import "MWInternalMacros.h"

@interface MWAnimatedImagePlayer () {
    NSRunLoopMode _runLoopMode;
}

@property (nonatomic, strong, readwrite) UIImage *currentFrame;
@property (nonatomic, assign, readwrite) NSUInteger currentFrameIndex;
@property (nonatomic, assign, readwrite) NSUInteger currentLoopCount;
@property (nonatomic, strong) id<MWAnimatedImageProvider> animatedProvider;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIImage *> *frameBuffer;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) BOOL bufferMiss;
@property (nonatomic, assign) BOOL needMWisplayWhenImageBecomesAvailable;
@property (nonatomic, assign) NSUInteger maxBufferCount;
@property (nonatomic, strong) NSOperationQueue *fetchQueue;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, strong) MWDisplayLink *displayLink;

@end

@implementation MWAnimatedImagePlayer

- (instancetype)initWithProvider:(id<MWAnimatedImageProvider>)provider {
    self = [super init];
    if (self) {
        NSUInteger animatedImageFrameCount = provider.animatedImageFrameCount;
        // Check the frame count
        if (animatedImageFrameCount <= 1) {
            return nil;
        }
        self.totalFrameCount = animatedImageFrameCount;
        // Get the current frame and loop count.
        self.totalLoopCount = provider.animatedImageLoopCount;
        self.animatedProvider = provider;
        self.playbackRate = 1.0;
#if MW_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
    }
    return self;
}

+ (instancetype)playerWithProvider:(id<MWAnimatedImageProvider>)provider {
    MWAnimatedImagePlayer *player = [[MWAnimatedImagePlayer alloc] initWithProvider:provider];
    return player;
}

#pragma mark - Life Cycle

- (void)dealloc {
#if MW_UIKIT
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification {
    [_fetchQueue cancelAllOperations];
    [_fetchQueue addOperationWithBlock:^{
        NSNumber *currentFrameIndex = @(self.currentFrameIndex);
        MW_LOCK(self.lock);
        NSArray *keys = self.frameBuffer.allKeys;
        // only keep the next frame for later rendering
        for (NSNumber * key in keys) {
            if (![key isEqualToNumber:currentFrameIndex]) {
                [self.frameBuffer removeObjectForKey:key];
            }
        }
        MW_UNLOCK(self.lock);
    }];
}

#pragma mark - Private
- (NSOperationQueue *)fetchQueue {
    if (!_fetchQueue) {
        _fetchQueue = [[NSOperationQueue alloc] init];
        _fetchQueue.maxConcurrentOperationCount = 1;
    }
    return _fetchQueue;
}

- (NSMutableDictionary<NSNumber *,UIImage *> *)frameBuffer {
    if (!_frameBuffer) {
        _frameBuffer = [NSMutableDictionary dictionary];
    }
    return _frameBuffer;
}

- (dispatch_semaphore_t)lock {
    if (!_lock) {
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (MWDisplayLink *)displayLink {
    if (!_displayLink) {
        _displayLink = [MWDisplayLink displayLinkWithTarget:self selector:@selector(displayDidRefresh:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.runLoopMode];
        [_displayLink stop];
    }
    return _displayLink;
}

- (void)setRunLoopMode:(NSRunLoopMode)runLoopMode {
    if ([_runLoopMode isEqual:runLoopMode]) {
        return;
    }
    if (_displayLink) {
        if (_runLoopMode) {
            [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:_runLoopMode];
        }
        if (runLoopMode.length > 0) {
            [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:runLoopMode];
        }
    }
    _runLoopMode = [runLoopMode copy];
}

- (NSRunLoopMode)runLoopMode {
    if (!_runLoopMode) {
        _runLoopMode = [[self class] defaultRunLoopMode];
    }
    return _runLoopMode;
}

#pragma mark - State Control

- (void)setupCurrentFrame {
    if (self.currentFrameIndex != 0) {
        return;
    }
    if ([self.animatedProvider isKindOfClass:[UIImage class]]) {
        UIImage *image = (UIImage *)self.animatedProvider;
        // Use the poster image if available
        #if MW_MAC
        UIImage *posterFrame = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
        #else
        UIImage *posterFrame = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
        #endif
        if (posterFrame) {
            self.currentFrame = posterFrame;
            MW_LOCK(self.lock);
            self.frameBuffer[@(self.currentFrameIndex)] = self.currentFrame;
            MW_UNLOCK(self.lock);
            [self handleFrameChange];
        }
    }
}

- (void)resetCurrentFrameStatus {
    // These should not trigger KVO, user don't need to receive an `index == 0, image == nil` callback.
    _currentFrame = nil;
    _currentFrameIndex = 0;
    _currentLoopCount = 0;
    _currentTime = 0;
    _bufferMiss = NO;
    _needMWisplayWhenImageBecomesAvailable = NO;
}

- (void)clearFrameBuffer {
    MW_LOCK(self.lock);
    [_frameBuffer removeAllObjects];
    MW_UNLOCK(self.lock);
}

#pragma mark - Animation Control
- (void)startPlaying {
    [self.displayLink start];
    // Setup frame
    if (self.currentFrameIndex == 0 && !self.currentFrame) {
        [self setupCurrentFrame];
    }
    // Calculate max buffer size
    [self calculateMaxBufferCount];
}

- (void)stopPlaying {
    [_fetchQueue cancelAllOperations];
    // Using `_displayLink` here because when UIImageView dealloc, it may trigger `[self stopAnimating]`, we already release the display link in MWAnimatedImageView's dealloc method.
    [_displayLink stop];
    // We need to reset the frame status, but not trigger any handle. This can ensure next time's playing status correct.
    [self resetCurrentFrameStatus];
}

- (void)pausePlaying {
    [_fetchQueue cancelAllOperations];
    [_displayLink stop];
}

- (BOOL)isPlaying {
    return _displayLink.isRunning;
}

- (void)seekToFrameAtIndex:(NSUInteger)index loopCount:(NSUInteger)loopCount {
    if (index >= self.totalFrameCount) {
        return;
    }
    self.currentFrameIndex = index;
    self.currentLoopCount = loopCount;
    self.currentFrame = [self.animatedProvider animatedImageFrameAtIndex:index];
    [self handleFrameChange];
}

#pragma mark - Core Render
- (void)displayDidRefresh:(MWDisplayLink *)displayLink {
    // If for some reason a wild call makes it through when we shouldn't be animating, bail.
    // Early return!
    if (!self.isPlaying) {
        return;
    }
    
    NSUInteger totalFrameCount = self.totalFrameCount;
    if (totalFrameCount <= 1) {
        // Total frame count less than 1, wrong configuration and stop animating
        [self stopPlaying];
        return;
    }
    
    NSTimeInterval playbackRate = self.playbackRate;
    if (playbackRate <= 0) {
        // Does not support <= 0 play rate
        [self stopPlaying];
        return;
    }
    
    // Calculate refresh duration
    NSTimeInterval duration = self.displayLink.duration;
    
    NSUInteger currentFrameIndex = self.currentFrameIndex;
    NSUInteger nextFrameIndex = (currentFrameIndex + 1) % totalFrameCount;
    
    // Check if we need to display new frame firstly
    BOOL bufferFull = NO;
    if (self.needMWisplayWhenImageBecomesAvailable) {
        UIImage *currentFrame;
        MW_LOCK(self.lock);
        currentFrame = self.frameBuffer[@(currentFrameIndex)];
        MW_UNLOCK(self.lock);
        
        // Update the current frame
        if (currentFrame) {
            MW_LOCK(self.lock);
            // Remove the frame buffer if need
            if (self.frameBuffer.count > self.maxBufferCount) {
                self.frameBuffer[@(currentFrameIndex)] = nil;
            }
            // Check whether we can stop fetch
            if (self.frameBuffer.count == totalFrameCount) {
                bufferFull = YES;
            }
            MW_UNLOCK(self.lock);
            
            // Update the current frame immediately
            self.currentFrame = currentFrame;
            [self handleFrameChange];
            
            self.bufferMiss = NO;
            self.needMWisplayWhenImageBecomesAvailable = NO;
        }
        else {
            self.bufferMiss = YES;
        }
    }
    
    // Check if we have the frame buffer
    if (!self.bufferMiss) {
        // Then check if timestamp is reached
        self.currentTime += duration;
        NSTimeInterval currentDuration = [self.animatedProvider animatedImageDurationAtIndex:currentFrameIndex];
        currentDuration = currentDuration / playbackRate;
        if (self.currentTime < currentDuration) {
            // Current frame timestamp not reached, return
            return;
        }
        
        // Otherwise, we should be ready to display next frame
        self.needMWisplayWhenImageBecomesAvailable = YES;
        self.currentFrameIndex = nextFrameIndex;
        self.currentTime -= currentDuration;
        NSTimeInterval nextDuration = [self.animatedProvider animatedImageDurationAtIndex:nextFrameIndex];
        nextDuration = nextDuration / playbackRate;
        if (self.currentTime > nextDuration) {
            // Do not skip frame
            self.currentTime = nextDuration;
        }
        
        // Update the loop count when last frame rendered
        if (nextFrameIndex == 0) {
            // Update the loop count
            self.currentLoopCount++;
            [self handleLoopChange];
            
            // if reached the max loop count, stop animating, 0 means loop indefinitely
            NSUInteger maxLoopCount = self.totalLoopCount;
            if (maxLoopCount != 0 && (self.currentLoopCount >= maxLoopCount)) {
                [self stopPlaying];
                return;
            }
        }
    }
    
    // Since we support handler, check animating state again
    if (!self.isPlaying) {
        return;
    }
    
    // Check if we should prefetch next frame or current frame
    // When buffer miss, means the decode speed is slower than render speed, we fetch current miss frame
    // Or, most cases, the decode speed is faster than render speed, we fetch next frame
    NSUInteger fetchFrameIndex = self.bufferMiss? currentFrameIndex : nextFrameIndex;
    UIImage *fetchFrame;
    MW_LOCK(self.lock);
    fetchFrame = self.bufferMiss? nil : self.frameBuffer[@(nextFrameIndex)];
    MW_UNLOCK(self.lock);
    
    if (!fetchFrame && !bufferFull && self.fetchQueue.operationCount == 0) {
        // Prefetch next frame in background queue
        id<MWAnimatedImageProvider> animatedProvider = self.animatedProvider;
        @weakify(self);
        NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            @strongify(self);
            if (!self) {
                return;
            }
            UIImage *frame = [animatedProvider animatedImageFrameAtIndex:fetchFrameIndex];

            BOOL isAnimating = self.displayLink.isRunning;
            if (isAnimating) {
                MW_LOCK(self.lock);
                self.frameBuffer[@(fetchFrameIndex)] = frame;
                MW_UNLOCK(self.lock);
            }
        }];
        [self.fetchQueue addOperation:operation];
    }
}

- (void)handleFrameChange {
    if (self.animationFrameHandler) {
        self.animationFrameHandler(self.currentFrameIndex, self.currentFrame);
    }
}

- (void)handleLoopChange {
    if (self.animationLoopHandler) {
        self.animationLoopHandler(self.currentLoopCount);
    }
}

#pragma mark - Util
- (void)calculateMaxBufferCount {
    NSUInteger bytes = CGImageGetBytesPerRow(self.currentFrame.CGImage) * CGImageGetHeight(self.currentFrame.CGImage);
    if (bytes == 0) bytes = 1024;
    
    NSUInteger max = 0;
    if (self.maxBufferSize > 0) {
        max = self.maxBufferSize;
    } else {
        // Calculate based on current memory, these factors are by experience
        NSUInteger total = [MWDeviceHelper totalMemory];
        NSUInteger free = [MWDeviceHelper freeMemory];
        max = MIN(total * 0.2, free * 0.6);
    }
    
    NSUInteger maxBufferCount = (double)max / (double)bytes;
    if (!maxBufferCount) {
        // At least 1 frame
        maxBufferCount = 1;
    }
    
    self.maxBufferCount = maxBufferCount;
}

+ (NSString *)defaultRunLoopMode {
    // Key off `activeProcessorCount` (as opposed to `processorCount`) since the system could shut down cores in certain situations.
    return [NSProcessInfo processInfo].activeProcessorCount > 1 ? NSRunLoopCommonModes : NSDefaultRunLoopMode;
}

@end
