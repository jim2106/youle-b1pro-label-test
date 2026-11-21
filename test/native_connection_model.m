#import "BlueDeviceInfoModel.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 1;
        NSString *payload = [NSString stringWithUTF8String:argv[1]];
        BlueDeviceInfoModel *device = [[BlueDeviceInfoModel new] fromJson:payload];
        return [device.deviceName isEqualToString:@"B1 Pro-A1"] &&
               [device.deviceHardwareAddress isEqualToString:@""] &&
               device.connectionState == 0 ? 0 : 1;
    }
}
