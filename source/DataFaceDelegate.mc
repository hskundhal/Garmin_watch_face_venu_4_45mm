import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class DataFaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as DataFaceView;

    function initialize(view as DataFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    // Called on touch and hold (press) - standard Garmin complication launch
    function onPress(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords = clickEvent.getCoordinates();
        return _view.handlePress(coords[0], coords[1]);
    }

    // Called on tap (touch-enabled devices)
    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords = clickEvent.getCoordinates();
        return _view.handlePress(coords[0], coords[1]);
    }
}

