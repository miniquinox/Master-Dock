#ifndef MultitouchSupportBridge_h
#define MultitouchSupportBridge_h

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

typedef enum {
    MTTouchStateNotTracking = 0,
    MTTouchStateStartInRange = 1,
    MTTouchStateHoverInRange = 2,
    MTTouchStateMakeTouch = 3,
    MTTouchStateTouching = 4,
    MTTouchStateBreak = 5,
    MTTouchStateLingerInRange = 6,
    MTTouchStateOutOfRange = 7
} MTTouchState;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    MTTouchState state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalizedPosition;
    float totalSize;
    float pressure;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolutePosition;
    int32_t unknown1;
    int32_t unknown2;
    float density;
} MTTouch;

typedef void* MTDeviceRef;
typedef int (*MTContactCallbackFunction)(MTDeviceRef device, MTTouch *touches, int numTouches, double timestamp, int frame);

// Bridge API for Swift
typedef void (*MDMultitouchSwiftCallback)(const MTTouch *touches, int count, double timestamp, void *context);

bool MDMultitouchStartListening(MDMultitouchSwiftCallback callback, void *context);
void MDMultitouchStopListening(void);
bool MDMultitouchIsAvailable(void);

#ifdef __cplusplus
}
#endif

#endif /* MultitouchSupportBridge_h */
