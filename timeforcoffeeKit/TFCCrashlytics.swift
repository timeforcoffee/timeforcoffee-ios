import Crashlytics
import Fabric

final public class TFCCrashlytics: NSObject, CrashlyticsDelegate {

    public static let sharedInstance = TFCCrashlytics()

    public func initCrashlytics() {
        #if !((arch(i386) || arch(x86_64)) && os(iOS))
            Crashlytics.sharedInstance().delegate = self;
            Fabric.with([Crashlytics.self])
            Crashlytics.sharedInstance().setUserIdentifier(TFCDataStore.sharedInstance.getTFCID())
        #endif
    }

    public func crashlyticsDidDetectReportForLastExecution(report: CLSReport, completionHandler: (Bool) -> Void) {
        report.setObjectValue(TFCDataStore.sharedInstance.getTFCID(), forKey: "TFCID")
        DLog("Crashlytics: crashedOnDate: \(report.crashedOnDate)", toFile: true);
        DLog("Crashlytics: isCrash: \(report.isCrash)", toFile: true);
        dispatch_async(dispatch_get_main_queue(), {
            completionHandler(true)
        })
    }

    public func crash() {
        Crashlytics.sharedInstance().crash()
    }
}

func DLog2CLS(format:String, text: [CVarArgType]) {
    CLSLogv(format, getVaList(text))
}
