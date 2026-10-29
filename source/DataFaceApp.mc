import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DataFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new DataFaceView() ];
    }
}
