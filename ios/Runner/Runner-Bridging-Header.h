#import "GeneratedPluginRegistrant.h"

// --- EZVIZ: un hueco de nulabilidad de la cabecera del SDK (copiado de la app del cliente)
//
// `EZGlobalSDK.h` está entero dentro de `NS_ASSUME_NONNULL_BEGIN`, incluido
// `probeDeviceInfo:deviceType:completion:`, cuya propia documentación dice que `deviceType`
// admite nil si no se conoce el modelo. Swift lo ve como `String` no opcional; esta función en
// línea hace la llamada desde Objective-C, donde nil SÍ es expresable.
#if __has_include(<EZOpenSDKFramework/EZOpenSDKFramework.h>)
#import <EZOpenSDKFramework/EZOpenSDKFramework.h>

static inline NSURLSessionDataTask *_Nullable OhmSafeEzvizProbeDeviceInfo(
    NSString *_Nonnull deviceSerial,
    void (^_Nonnull completion)(EZProbeDeviceInfo *_Nullable deviceInfo,
                                NSError *_Nullable error)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  return [EZGlobalSDK probeDeviceInfo:deviceSerial deviceType:nil completion:completion];
#pragma clang diagnostic pop
}
#endif
