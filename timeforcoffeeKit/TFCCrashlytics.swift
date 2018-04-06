import Crashlytics
import Fabric

final public class TFCCrashlytics: NSObject, CrashlyticsDelegate {

    public static let sharedInstance = TFCCrashlytics()

    public func initCrashlytics() {
        #if !(targetEnvironment(simulator))
            DispatchQueue.main.async {
                Crashlytics.sharedInstance().delegate = self;
                Fabric.with([Crashlytics.self])
                Crashlytics.sharedInstance().setUserIdentifier(TFCDataStore.sharedInstance.getTFCID())
            }
        #endif
    }

    @nonobjc public func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        report.setObjectValue(TFCDataStore.sharedInstance.getTFCID(), forKey: "TFCID")
        DLog("Crashlytics: crashedOnDate: \(String(describing: report.crashedOnDate))", toFile: true);
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
    #if !(targetEnvironment(simulator))
        CLSLogv(format, getVaList(text))
    #endif
}
