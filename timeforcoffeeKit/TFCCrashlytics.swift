import Crashlytics
import Fabric

final public class TFCCrashlytics: NSObject, CrashlyticsDelegate {

    public static let sharedInstance = TFCCrashlytics()

    public func initCrashlytics() {
        #if !((arch(i386) || arch(x86_64)) && os(iOS))
            DispatchQueue.main.async {
                Crashlytics.sharedInstance().delegate = self;
                Fabric.with([Crashlytics.self])
                Crashlytics.sharedInstance().setUserIdentifier(TFCDataStore.sharedInstance.getTFCID())
            }
        #endif
    }

    @nonobjc public func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        report.setObjectValue(TFCDataStore.sharedInstance.getTFCID(), forKey: "TFCID")
        DLog("Crashlytics: crashedOnDate: \(report.crashedOnDate)", toFile: true);
        DLog("Crashlytics: isCrash: \(report.isCrash)", toFile: true);
        DispatchQueue.main.async(execute: {
            completionHandler(true)
        })
    }

    public func crash() {
        Crashlytics.sharedInstance().crash()
    }
}

func DLog2CLS(_ format:String, text: [CVarArg]) {
    #if !((arch(i386) || arch(x86_64)) && os(iOS))
        CLSLogv(format, getVaList(text))
    #endif
}
