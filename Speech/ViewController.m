//
//  ViewController.m
//  Speech
//
//  Created by PatrickY on 2017/11/28.
//  Copyright © 2017年 PatrickY. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<SFSpeechRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UITextView *showWords;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) SFSpeechRecognizer *recognizer;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recgnitionRequset;

@end

@implementation ViewController

-(AVAudioEngine *)audioEngine {
    if (!_audioEngine) {
        _audioEngine = [[AVAudioEngine alloc] init];
    }
    
    return _audioEngine;
}

-(SFSpeechRecognizer *)recognizer {
    if (!_recognizer) {
        //设置语言
        NSLocale *local = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        _recognizer = [[SFSpeechRecognizer alloc] initWithLocale:local];
        _recognizer.delegate = self;
    }
    
    return _recognizer;
}

//申请权限
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    __weak typeof(self) weakSelf = self;
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
       
            switch(status) {
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                    weakSelf.recordButton.enabled = NO;
                    [weakSelf.recordButton setTitle:@"语音识别未授权" forState:UIControlStateDisabled];
                    break;
                case SFSpeechRecognizerAuthorizationStatusDenied:
                    weakSelf.recordButton.enabled  = NO;
                    [weakSelf.recordButton setTitle:@"用户未授权使用" forState:UIControlStateDisabled];
                    break;
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                    weakSelf.recordButton.enabled = NO;
                    [weakSelf.recordButton setTitle:@"语音识别受限" forState:UIControlStateDisabled];
                    break;
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                    weakSelf.recordButton.enabled = YES;
                    [weakSelf.recordButton setTitle: @"开始录音" forState:UIControlStateNormal];
                    break;
                    
                default:
                    break;
            }
            
        });
    }];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _recordButton.enabled = NO;
}

//开始录音
- (IBAction)startRecording:(id)sender {
    
    if ([self.audioEngine isRunning]) {
        [self.audioEngine stop];
        if (_recgnitionRequset) {
            [_recgnitionRequset endAudio];
        }
        self.recordButton.enabled = NO;
        [self.recordButton setTitle:@"正在停止" forState:UIControlStateDisabled];
        }
    else {
        [self startRecording];
        [self.recordButton setTitle:@"停止录音" forState:UIControlStateNormal];
    }
    
}

-(void)startRecording {
    
    if (_recognitionTask) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
    }
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error;
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    NSParameterAssert(!error);
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    NSParameterAssert(!error);
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    NSParameterAssert(!error);
    
    _recgnitionRequset = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    AVAudioInputNode *inputNone = self.audioEngine.inputNode;
    NSAssert(inputNone, @"录入设备没有准备好");
    NSAssert(_recgnitionRequset, @"请求初始化失败");
    _recgnitionRequset.shouldReportPartialResults = YES;
    __weak typeof(self) weakSelf = self;
    _recognitionTask = [self.recognizer recognitionTaskWithRequest:_recgnitionRequset resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        BOOL isFinal = NO;
        if (result) {
            strongSelf.showWords.text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
        }
        if (error || isFinal) {
            [self.audioEngine stop];
            [inputNone removeTapOnBus:0];
            strongSelf.recognitionTask = nil;
            strongSelf.recgnitionRequset = nil;
            strongSelf.recordButton.enabled = YES;
            self.showWords.text = @"显示结果：";
            [strongSelf.recordButton setTitle:@"开始录音" forState:UIControlStateNormal];
        }
    }];
    
    AVAudioFormat *recordingFormat = [inputNone outputFormatForBus:0];
    //添加tap之前移除上一个
    [inputNone removeTapOnBus:0];
    [inputNone installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.recgnitionRequset) {
            [strongSelf.recgnitionRequset appendAudioPCMBuffer:buffer];
        }
        
    }];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:&error];
    NSParameterAssert(!error);
    self.showWords.text = @"正在录音";
    
}

#pragma mark -- delegate
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    
    if (available) {
        self.recordButton.enabled = YES;
        [self.recordButton setTitle:@"开始录音" forState:UIControlStateNormal];
    } else {
        self.recordButton.enabled = NO;
        [self.recordButton setTitle:@"语音识别不可用" forState:UIControlStateDisabled];
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

