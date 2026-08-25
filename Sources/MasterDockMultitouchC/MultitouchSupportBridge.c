#include "MultitouchSupportBridge.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <CoreFoundation/CoreFoundation.h>

typedef MTDeviceRef (*MTDeviceCreateDefaultFn)(void);
typedef CFArrayRef (*MTDeviceCreateListFn)(void);
typedef void (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallbackFunction);
typedef void (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallbackFunction);
typedef void (*MTDeviceStartFn)(MTDeviceRef, int);
typedef void (*MTDeviceStopFn)(MTDeviceRef, int);
typedef void (*MTDeviceReleaseFn)(MTDeviceRef);

static void *s_frameworkHandle = NULL;
static MTDeviceCreateDefaultFn s_createDefault = NULL;
static MTDeviceCreateListFn s_createList = NULL;
static MTRegisterContactFrameCallbackFn s_registerCallback = NULL;
static MTUnregisterContactFrameCallbackFn s_unregisterCallback = NULL;
static MTDeviceStartFn s_startDevice = NULL;
static MTDeviceStopFn s_stopDevice = NULL;
static MTDeviceReleaseFn s_releaseDevice = NULL;

static MTDeviceRef s_activeDevice = NULL;
static MDMultitouchSwiftCallback s_swiftCallback = NULL;
static void *s_swiftContext = NULL;
static pthread_mutex_t s_mutex = PTHREAD_MUTEX_INITIALIZER;
static bool s_isListening = false;

static bool loadFrameworkIfNeeded(void) {
    if (s_frameworkHandle != NULL) {
        return true;
    }
    
    s_frameworkHandle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY);
    if (!s_frameworkHandle) {
        return false;
    }
    
    s_createDefault = (MTDeviceCreateDefaultFn)dlsym(s_frameworkHandle, "MTDeviceCreateDefault");
    s_createList = (MTDeviceCreateListFn)dlsym(s_frameworkHandle, "MTDeviceCreateList");
    s_registerCallback = (MTRegisterContactFrameCallbackFn)dlsym(s_frameworkHandle, "MTRegisterContactFrameCallback");
    s_unregisterCallback = (MTUnregisterContactFrameCallbackFn)dlsym(s_frameworkHandle, "MTUnregisterContactFrameCallback");
    s_startDevice = (MTDeviceStartFn)dlsym(s_frameworkHandle, "MTDeviceStart");
    s_stopDevice = (MTDeviceStopFn)dlsym(s_frameworkHandle, "MTDeviceStop");
    s_releaseDevice = (MTDeviceReleaseFn)dlsym(s_frameworkHandle, "MTDeviceRelease");
    
    return (s_createDefault && s_registerCallback && s_startDevice && s_stopDevice);
}

static int internalContactCallback(MTDeviceRef device, MTTouch *touches, int numTouches, double timestamp, int frame) {
    pthread_mutex_lock(&s_mutex);
    MDMultitouchSwiftCallback cb = s_swiftCallback;
    void *ctx = s_swiftContext;
    pthread_mutex_unlock(&s_mutex);
    
    if (cb && numTouches > 0 && touches != NULL) {
        cb(touches, numTouches, timestamp, ctx);
    }
    return 0;
}

bool MDMultitouchIsAvailable(void) {
    pthread_mutex_lock(&s_mutex);
    bool available = loadFrameworkIfNeeded();
    pthread_mutex_unlock(&s_mutex);
    return available;
}

bool MDMultitouchStartListening(MDMultitouchSwiftCallback callback, void *context) {
    pthread_mutex_lock(&s_mutex);
    
    if (s_isListening) {
        pthread_mutex_unlock(&s_mutex);
        return true;
    }
    
    if (!loadFrameworkIfNeeded()) {
        pthread_mutex_unlock(&s_mutex);
        return false;
    }
    
    s_swiftCallback = callback;
    s_swiftContext = context;
    
    s_activeDevice = s_createDefault();
    if (!s_activeDevice) {
        pthread_mutex_unlock(&s_mutex);
        return false;
    }
    
    s_registerCallback(s_activeDevice, internalContactCallback);
    s_startDevice(s_activeDevice, 0);
    s_isListening = true;
    
    pthread_mutex_unlock(&s_mutex);
    return true;
}

void MDMultitouchStopListening(void) {
    pthread_mutex_lock(&s_mutex);
    
    if (!s_isListening) {
        pthread_mutex_unlock(&s_mutex);
        return;
    }
    
    if (s_activeDevice) {
        if (s_unregisterCallback) {
            s_unregisterCallback(s_activeDevice, internalContactCallback);
        }
        if (s_stopDevice) {
            s_stopDevice(s_activeDevice, 0);
        }
        if (s_releaseDevice) {
            s_releaseDevice(s_activeDevice);
        }
        s_activeDevice = NULL;
    }
    
    s_swiftCallback = NULL;
    s_swiftContext = NULL;
    s_isListening = false;
    
    pthread_mutex_unlock(&s_mutex);
}
