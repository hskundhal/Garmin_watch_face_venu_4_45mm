import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DataFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new DataFaceView();
        if (WatchUi has :WatchFaceDelegate) {
            return [ view, new DataFaceDelegate(view) ];
        }
        return [ view ];
    }
}
