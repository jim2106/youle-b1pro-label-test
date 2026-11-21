#import "GeneratedPluginRegistrant.h"
#import <niimbot_print/JCAPI.h>

static inline NSString *YouleConnectedPrinter(void) { return [JCAPI connectingPrinterName]; }
static inline void YouleCancelConnection(void) { [JCAPI closePrinter]; }
