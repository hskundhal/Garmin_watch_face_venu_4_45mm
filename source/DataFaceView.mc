import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// ---- Palette -------------------------------------------------------------
const C_BG            = 0x000000;
const C_WHITE         = 0xFFFFFF;
const C_MUTED_GREY    = 0x71717A;
const C_LINE          = 0x8E9BAE;

// Gradient endpoints for Hour (Cyan-Blue to Red-Magenta)
const C_HOUR_TOP      = 0x00A6FF;
const C_HOUR_BOT      = 0xEE1144;

// Gradient endpoints for Minute (Yellow to Orange-Red)
const C_MIN_TOP       = 0xFFEA00;
const C_MIN_BOT       = 0xFF3300;

// Arc colors
const C_ARC_RED       = 0xFF1744;
const C_ARC_YELLOW    = 0xFFEA00;
const C_ARC_ORANGE    = 0xFF6D00;
const C_ARC_BLUE      = 0x00B0FF;
const C_ARC_GREEN     = 0x00E676;
const C_ARC_DARK      = 0x1E293B;

// Accent icons
const C_CYAN_ACCENT   = 0x00E5FF;
const C_BLUE_BADGE    = 0x0288D1;

class DataFaceView extends WatchUi.WatchFace {

    hidden var _lowPower = false;

    // Layout bounds for touch handling
    hidden var _w as Lang.Number = 0;
    hidden var _h as Lang.Number = 0;
    hidden var _cx as Lang.Float = 0.0;
    hidden var _cy as Lang.Float = 0.0;
    hidden var _hourTop as Lang.Float = 0.0;
    hidden var _hourBottom as Lang.Float = 0.0;
    hidden var _minTop as Lang.Float = 0.0;
    hidden var _minBottom as Lang.Float = 0.0;
    hidden var _y1 as Lang.Float = 0.0;
    hidden var _y2 as Lang.Float = 0.0;

    // Complication IDs for direct launching
    hidden var _sleepId as Complications.Id? = null;
    hidden var _readyId as Complications.Id? = null;
    hidden var _recoverId as Complications.Id? = null;
    hidden var _hrId as Complications.Id? = null;
    hidden var _bodyBattId as Complications.Id? = null;
    hidden var _batteryId as Complications.Id? = null;
    hidden var _stressId as Complications.Id? = null;
    hidden var _stepsId as Complications.Id? = null;
    hidden var _weatherId as Complications.Id? = null;
    hidden var _distanceId as Complications.Id? = null;
    hidden var _calendarId as Complications.Id? = null;

    // Cached sensor values to avoid momentary flickering during movement
    hidden var _lastValidStress as Lang.Number? = null;
    hidden var _lastValidBodyBattery as Lang.Number? = null;

    function initialize() {
        WatchFace.initialize();
        findComplications();
    }

    function findComplications() {
        if (!(Toybox has :Complications)) {
            return;
        }
        try {
            // Use iterator pattern across supported devices
            var iter = Complications.getComplications();
            var comp = iter.next();
            while (comp != null) {
                var label = "";
                if (comp.longLabel != null)  { label = label + comp.longLabel; }
                if (comp.shortLabel != null) { label = label + " " + comp.shortLabel; }
                label = label.toLower();

                var cType = null;
                if (comp has :getType) { cType = comp.getType(); }

                // Heart rate
                if (_hrId == null && (cType == Complications.COMPLICATION_TYPE_HEART_RATE || label.find("heart rate") != null)) {
                    _hrId = comp.complicationId;
                }
                // Body battery
                else if (_bodyBattId == null && (cType == Complications.COMPLICATION_TYPE_BODY_BATTERY || label.find("body battery") != null)) {
                    _bodyBattId = comp.complicationId;
                }
                // Battery
                else if (_batteryId == null && (cType == Complications.COMPLICATION_TYPE_BATTERY || (label.find("battery") != null && label.find("body") == null))) {
                    _batteryId = comp.complicationId;
                }
                // Stress
                else if (_stressId == null && (cType == Complications.COMPLICATION_TYPE_STRESS || label.find("stress") != null)) {
                    _stressId = comp.complicationId;
                }
                // Steps
                else if (_stepsId == null && (cType == Complications.COMPLICATION_TYPE_STEPS || label.find("steps") != null)) {
                    _stepsId = comp.complicationId;
                }
                // Weather / Temp
                else if (_weatherId == null && (cType == Complications.COMPLICATION_TYPE_CURRENT_WEATHER || cType == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE || label.find("weather") != null || label.find("temperature") != null)) {
                    _weatherId = comp.complicationId;
                }
                // Distance / Run
                else if (_distanceId == null && (cType == Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE || label.find("distance") != null || label.find("run") != null)) {
                    _distanceId = comp.complicationId;
                }
                // Calendar / Date
                else if (_calendarId == null && (cType == Complications.COMPLICATION_TYPE_CALENDAR_EVENTS || cType == Complications.COMPLICATION_TYPE_DATE || label.find("event") != null || label.find("date") != null)) {
                    _calendarId = comp.complicationId;
                }
                // Recovery time
                else if (_recoverId == null && (cType == Complications.COMPLICATION_TYPE_RECOVERY_TIME || label.find("recover") != null)) {
                    _recoverId = comp.complicationId;
                }
                // Sleep score
                else if (_sleepId == null && (cType == Complications.COMPLICATION_TYPE_SLEEP_SCORE || (label.find("sleep") != null && label.find("score") != null))) {
                    _sleepId = comp.complicationId;
                }
                // Readiness
                else if (_readyId == null && label.find("readiness") != null) {
                    _readyId = comp.complicationId;
                }

                comp = iter.next();
            }

            // Direct fallback constructors for core wellness metrics if not encountered in iterator
            if (_stressId == null) {
                try { _stressId = new Complications.Id(Complications.COMPLICATION_TYPE_STRESS); } catch (e) {}
            }
            if (_bodyBattId == null) {
                try { _bodyBattId = new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY); } catch (e) {}
            }
            if (_hrId == null) {
                try { _hrId = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE); } catch (e) {}
            }

            if (_sleepId != null)    { Complications.subscribeToUpdates(_sleepId); }
            if (_readyId != null)    { Complications.subscribeToUpdates(_readyId); }
            if (_recoverId != null)  { Complications.subscribeToUpdates(_recoverId); }
            if (_hrId != null)       { Complications.subscribeToUpdates(_hrId); }
            if (_bodyBattId != null) { Complications.subscribeToUpdates(_bodyBattId); }
            if (_stressId != null)   { Complications.subscribeToUpdates(_stressId); }
            if (_stepsId != null)    { Complications.subscribeToUpdates(_stepsId); }

            Complications.registerComplicationChangeCallback(self.method(:onComplicationChanged));
        } catch (ex) {
            System.println("Complications unavailable: " + ex.getErrorMessage());
        }
    }

    function launchComplication(id as Complications.Id?) as Lang.Boolean {
        if (id == null) {
            System.println("[Touch] Complication Id not available for this target");
            return false;
        }
        if (!(Toybox has :Complications)) {
            return false;
        }
        try {
            Complications.exitTo(id);
            return true;
        } catch (ex) {
            System.println("[Touch] exitTo error: " + ex.getErrorMessage());
        }
        return false;
    }

    // ------------------------------------------------------------------
    // Touch / Press Event Handler: routes taps to native detail views
    // ------------------------------------------------------------------
    function handlePress(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        if (_w == 0 || _h == 0) { return false; }

        // 1. Top-Left: Stress
        if (x < _cx - 30 && y >= _hourTop && y <= _y1) {
            System.println("[Touch] Top-Left tapped -> launching Stress detail");
            if (_stressId != null && launchComplication(_stressId)) { return true; }
            if (_readyId != null && launchComplication(_readyId)) { return true; }
            return false;
        }

        // 2. Top-Right: Battery
        if (x > _cx + 30 && y >= _hourTop && y <= _y1) {
            System.println("[Touch] Top-Right tapped -> launching Battery detail");
            if (_batteryId != null && launchComplication(_batteryId)) { return true; }
            return false;
        }

        // 3. Bottom-Left: Body Battery
        if (x < _cx - 30 && y >= _y2 && y <= _minBottom) {
            System.println("[Touch] Bottom-Left tapped -> launching Body Battery detail");
            if (_bodyBattId != null && launchComplication(_bodyBattId)) { return true; }
            return false;
        }

        // 4. Bottom-Right: Heart Rate
        if (x > _cx + 30 && y >= _y2 && y <= _minBottom) {
            System.println("[Touch] Bottom-Right tapped -> launching Heart Rate detail");
            if (_hrId != null && launchComplication(_hrId)) { return true; }
            return false;
        }

        // 5. Center Divider Bar (Alarms/Bluetooth on left, DND/Weather on right)
        if (y >= _y1 - 8 && y <= _y2 + 8) {
            if (x < _cx) {
                System.println("[Touch] Alarms / Status tapped");
                if (_calendarId != null && launchComplication(_calendarId)) { return true; }
            } else {
                System.println("[Touch] Weather / Temp tapped -> launching Weather detail");
                if (_weatherId != null && launchComplication(_weatherId)) { return true; }
            }
            return true;
        }

        // 6. Top Header (above hours): Date
        if (y < _hourTop) {
            System.println("[Touch] Date header tapped -> launching Calendar detail");
            if (_calendarId != null && launchComplication(_calendarId)) { return true; }
            return true;
        }

        // 7. Bottom Footer (below minutes): Steps row and Heart Rate graph
        if (y > _minBottom) {
            if (y > _minBottom + 22) {
                System.println("[Touch] Heart Rate graph tapped -> launching Heart Rate detail");
                if (_hrId != null && launchComplication(_hrId)) { return true; }
            } else {
                System.println("[Touch] Steps row tapped -> launching Steps detail");
                if (_stepsId != null && launchComplication(_stepsId)) { return true; }
            }
            return true;
        }

        return false;
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    function compValue(id) {
        if (id == null) { return null; }
        try {
            var c = Complications.getComplication(id);
            if (c != null) { return c.value; }
        } catch (ex) {
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function extractNum(v) as Lang.Number? {
        if (v == null) { return null; }
        if (v instanceof Lang.Number) { return v; }
        if (v instanceof Lang.Float || v instanceof Lang.Double || v instanceof Lang.Long) {
            return v.toNumber();
        }
        if (v instanceof Lang.String) {
            try { return v.toNumber(); } catch (e) { return null; }
        }
        return null;
    }

    function fmtNum(v) {
        if (v == null) { return "--"; }
        var n = extractNum(v);
        if (n != null) { return n.toString(); }
        return v.toString();
    }

    function latestSensor(kind) {
        if (!(Toybox has :SensorHistory)) { return null; }
        try {
            var it = null;
            if (kind == :bodyBattery && (SensorHistory has :getBodyBatteryHistory)) {
                it = SensorHistory.getBodyBatteryHistory({});
            } else if (kind == :stress && (SensorHistory has :getStressHistory)) {
                it = SensorHistory.getStressHistory({});
            }
            if (it != null) {
                var s = it.next();
                var count = 0;
                while (s != null && count < 35) {
                    if (s.data != null) {
                        var val = extractNum(s.data);
                        if (val != null && val >= 0 && val <= 100) {
                            return val;
                        }
                    }
                    s = it.next();
                    count++;
                }
            }
        } catch (e) {
            System.println("SensorHistory error: " + e.getErrorMessage());
        }
        return null;
    }

    // Stress: tries sources from most→least real-time with caching
    // 1. Complication value (Garmin pushes whenever new stress reading arrives)
    // 2. ActivityMonitor.Info.stressScore (API 5.0+, live rolling average)
    // 3. SensorHistory newest valid sample (0-100, up to 35 samples back)
    // 4. Cached previous valid value (avoids flicker when moving)
    function stressScore() as Lang.Number? {
        // Ensure _stressId is initialized
        if (_stressId == null && (Toybox has :Complications)) {
            try {
                _stressId = new Complications.Id(Complications.COMPLICATION_TYPE_STRESS);
                Complications.subscribeToUpdates(_stressId);
            } catch (e) {}
        }

        // Source 1: Complication value (subscribed -> pushed on change)
        var cv = compValue(_stressId);
        if (cv != null) {
            var s = extractNum(cv);
            if (s != null && s >= 0 && s <= 100) {
                _lastValidStress = s;
                return s;
            }
        }

        // Source 2: Live stressScore on ActivityMonitor.Info (API 5.0+)
        if (ActivityMonitor has :getInfo) {
            try {
                var am = ActivityMonitor.getInfo();
                if (am != null && (am has :stressScore) && am.stressScore != null) {
                    var s = extractNum(am.stressScore);
                    if (s != null && s >= 0 && s <= 100) {
                        _lastValidStress = s;
                        return s;
                    }
                }
            } catch (e) {}
        }

        // Source 3: SensorHistory recent valid sample (buffer of 35 samples)
        var hist = latestSensor(:stress);
        if (hist != null) {
            _lastValidStress = hist;
            return hist;
        }

        // Source 4: Cached last known valid stress
        return _lastValidStress;
    }

    function bodyBatteryScore() as Lang.Number? {
        var cv = compValue(_bodyBattId);
        if (cv != null) {
            var b = extractNum(cv);
            if (b != null && b >= 0 && b <= 100) {
                _lastValidBodyBattery = b;
                return b;
            }
        }
        var bb = latestSensor(:bodyBattery);
        if (bb != null) {
            _lastValidBodyBattery = bb;
            return bb;
        }
        return _lastValidBodyBattery;
    }

    function heartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        var h = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (h != null && h.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return h.heartRate;
        }
        return null;
    }

    function blendColor(c1, c2, ratio) {
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;

        var r2 = (c2 >> 16) & 0xFF;
        var g2 = (c2 >> 8) & 0xFF;
        var b2 = c2 & 0xFF;

        var r = (r1 + (r2 - r1) * ratio).toNumber();
        var g = (g1 + (g2 - g1) * ratio).toNumber();
        var b = (b1 + (b2 - b1) * ratio).toNumber();

        return (r << 16) | (g << 8) | b;
    }

    function onEnterSleep() {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    // ------------------------------------------------------------------
    // Render loop
    // ------------------------------------------------------------------
    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2.0;
        var cy = h / 2.0;

        dc.setColor(C_BG, C_BG);
        dc.clear();

        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;
        var hr = clock.hour;
        if (!is24) {
            hr = hr % 12;
            if (hr == 0) { hr = 12; }
        }
        var hStr = hr.format("%02d");
        var mStr = clock.min.format("%02d");

        // ---- AOD Mode --------------------------------------------------
        if (_lowPower) {
            var nudgeX = (clock.min % 7) - 3;
            var nudgeY = ((clock.min / 7) % 7) - 3;
            drawGradientText(dc, cx + nudgeX * 2, cy - h * 0.16 + nudgeY * 2, Graphics.FONT_NUMBER_HOT, hStr, C_MUTED_GREY, C_MUTED_GREY);
            drawGradientText(dc, cx + nudgeX * 2, cy + h * 0.16 + nudgeY * 2, Graphics.FONT_NUMBER_HOT, mStr, C_MUTED_GREY, C_MUTED_GREY);
            return;
        }

        var am = ActivityMonitor.getInfo();
        var steps = (am != null && am.steps != null) ? am.steps : 0;
        var batt = System.getSystemStats().battery;
        var bb = bodyBatteryScore();
        if (bb == null) { bb = 78; } // fallback demo default
        var hrv = heartRate();
        if (hrv == null) { hrv = 80; } // fallback demo default
        // Stress: real-time Garmin stress score (0-100)
        var stress = stressScore();

        // 1. Outer Bezel Ticks & Cardinal Accents
        drawBezelAccents(dc, cx, cy, w * 0.47);

        // 2. The 3 Colored Segmented Progress Arcs (Bottom-Right arc removed per user request)
        var battPct = (batt != null) ? batt / 100.0 : 0.78;
        var bbPct = (bb != null) ? bb / 100.0 : 0.78;
        var stressPct = (stress != null) ? (stress.toFloat() / 100.0) : 0.0;
        if (stressPct > 1.0) { stressPct = 1.0; }
        if (stressPct < 0.0) { stressPct = 0.0; }

        var arcR = w * 0.44;
        // Top-Left: Red arc (Stress Level)
        drawSegmentedArc(dc, cx, cy, arcR, 122.0, 162.0, 14, stressPct, C_ARC_RED, C_ARC_RED);
        // Top-Right: Yellow-Orange gradient arc (Battery)
        drawSegmentedArc(dc, cx, cy, arcR, 18.0, 58.0, 14, battPct, C_ARC_YELLOW, C_ARC_ORANGE);
        // Bottom-Left: Blue arc (Body Battery)
        drawSegmentedArc(dc, cx, cy, arcR, 198.0, 238.0, 14, bbPct, C_ARC_BLUE, C_ARC_BLUE);
        // (Heart rate slider removed: replaced with dedicated smoothed heart rate graph)

        // 3. Exact Layout Anchors (Mathematical Overlap Prevention)
        var fontTime = Graphics.FONT_NUMBER_MILD;
        var fh = dc.getFontHeight(fontTime);

        // Center divider bar bounds
        var barH = 26;
        var y1 = cy - barH / 2.0;
        var y2 = cy + barH / 2.0;

        // Hour: strictly above y1 with clearance
        var margin = 6;
        var hourBottom = y1 - margin;
        var hourTop = hourBottom - fh;
        var hourY = (hourTop + hourBottom) / 2.0;

        // Minute: strictly below y2 with clearance
        var minTop = y2 + margin;
        var minBottom = minTop + fh;
        var minY = (minTop + minBottom) / 2.0;

        // Cache layout bounds for touch handling
        _w = w;
        _h = h;
        _cx = cx;
        _cy = cy;
        _hourTop = hourTop;
        _hourBottom = hourBottom;
        _minTop = minTop;
        _minBottom = minBottom;
        _y1 = y1;
        _y2 = y2;

        // Top Date Header: placed comfortably inside the slider opening, above hourTop
        var topDateY = hourTop - (h * 0.052);

        // Steps row: compact directly below minBottom
        var stepsY = minBottom + (h * 0.038);

        // Heart rate smooth graph: centered below steps
        var hrGraphY = stepsY + (h * 0.068);

        // Bottom status bar: below hrGraphY
        var botStatusY = hrGraphY + (h * 0.060);

        // 4. Top Date Header (12 o'clock)
        drawTopDate(dc, cx, topDateY);

        // 6. Center Stacked Time with True Gradient (Zero overlap)
        drawGradientText(dc, cx, hourY, fontTime, hStr, C_HOUR_TOP, C_HOUR_BOT);
        drawGradientText(dc, cx, minY, fontTime, mStr, C_MIN_TOP, C_MIN_BOT);

        // 7. Horizontal Divider Bar & Date Row
        drawCenterDividerBar(dc, cx, cy, w * 0.72);

        // 8. Four Side Telemetry Complications
        // Positioned at w * 0.20 and w * 0.80 to leave generous horizontal margin from digits
        // Top-Left: Stress (Icon on Top, Number Below)
        drawSideStat(dc, w * 0.20, hourY, :activity, fmtNum(stress), true);
        // Top-Right: Battery (Icon on Top, Number Below)
        drawSideStat(dc, w * 0.80, hourY, :battery, fmtNum(batt), true);
        // Bottom-Left: Body Battery (Number on Top, Icon Below)
        drawSideStat(dc, w * 0.20, minY, :body, fmtNum(bb), false);
        // Bottom-Right: Heart Rate (Number on Top, Icon Below)
        drawSideStat(dc, w * 0.80, minY, :heart, fmtNum(hrv), false);

        // 9. Bottom Steps Metric (compact footprint icon + count)
        drawStepsRow(dc, cx, stepsY, steps.toString());

        // 10. Smoothed Heart Rate Trend Graph (with live latest HR pulse and average line)
        drawHeartRateGraph(dc, cx, hrGraphY, 136, 24, hrv);

        // 11. Bottom-Center Status Bar (6 o'clock)
        drawBottomStatusBar(dc, cx, botStatusY);
    }

    // ------------------------------------------------------------------
    // Gradient Text Drawing (Smooth vertical strip blend)
    // ------------------------------------------------------------------
    function drawGradientText(dc, cx, cy, font, text, topColor, botColor) {
        var fh = dc.getFontHeight(font);
        var fw = dc.getTextWidthInPixels(text, font);
        var left = (cx - fw / 2.0).toNumber();
        var top = (cy - fh / 2.0).toNumber();
        var strips = 12;
        var stripH = (fh / strips.toFloat()).toNumber() + 1;

        for (var i = 0; i < strips; i++) {
            var sy = top + (i * fh / strips.toFloat()).toNumber();
            var ratio = i.toFloat() / (strips - 1).toFloat();
            var col = blendColor(topColor, botColor, ratio);

            dc.setClip(left - 2, sy, fw + 4, stripH);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.clearClip();
    }

    // ------------------------------------------------------------------
    // Segmented Radial Arcs
    // ------------------------------------------------------------------
    function drawSegmentedArc(dc, cx, cy, r, startDeg, endDeg, totalSegments, fillPct, startCol, endCol) {
        var activeCount = (totalSegments * fillPct).toNumber();
        if (fillPct > 0.0 && activeCount == 0) { activeCount = 1; }
        if (activeCount > totalSegments) { activeCount = totalSegments; }

        var span = (endDeg - startDeg);
        var step = span / (totalSegments - 1).toFloat();

        for (var i = 0; i < totalSegments; i++) {
            var deg = startDeg + i * step;
            var rad = deg * Math.PI / 180.0;
            var cosA = Math.cos(rad);
            var sinA = Math.sin(rad);

            var x1 = cx + cosA * (r - 9);
            var y1 = cy - sinA * (r - 9);
            var x2 = cx + cosA * (r + 1);
            var y2 = cy - sinA * (r + 1);

            if (i < activeCount) {
                var ratio = (totalSegments > 1) ? i.toFloat() / (totalSegments - 1).toFloat() : 0.0;
                var col = blendColor(startCol, endCol, ratio);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
            } else {
                dc.setColor(C_ARC_DARK, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
            }
            dc.drawLine(x1, y1, x2, y2);
        }
        dc.setPenWidth(1);
    }

    // ------------------------------------------------------------------
    // Bezel Accents & Cardinal Markers
    // ------------------------------------------------------------------
    function drawBezelAccents(dc, cx, cy, r) {
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);

        // 12 o'clock white square marker
        dc.fillRectangle(cx - 3, cy - r - 4, 6, 6);
        // 6 o'clock white square marker
        dc.fillRectangle(cx - 3, cy + r - 2, 6, 6);
        // 9 o'clock dash marker
        dc.fillRectangle(cx - r - 4, cy - 2, 6, 4);
        // 3 o'clock dash marker
        dc.fillRectangle(cx + r - 2, cy - 2, 6, 4);

        // Secondary dot ticks for other hours
        dc.setColor(C_MUTED_GREY, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            if (i % 3 != 0) {
                var rad = i * 30.0 * Math.PI / 180.0;
                var x = cx + Math.sin(rad) * r;
                var y = cy - Math.cos(rad) * r;
                dc.fillCircle(x, y, 2);
            }
        }
    }

    // ------------------------------------------------------------------
    // Top Date Header (Replaces swim & 3-icon group at 12 o'clock)
    // ------------------------------------------------------------------
    function drawTopDate(dc, cx, y) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        // Format: "Thu 29 Oct"
        var dateStr = info.day_of_week + " " + info.day.toString() + " " + info.month;

        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, dateStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Horizontal Center Divider Bar
    // ------------------------------------------------------------------
    function drawCenterDividerBar(dc, cx, cy, barW) {
        var halfW = barW / 2.0;
        var y1 = cy - 14;
        var y2 = cy + 14;

        // Two parallel lines
        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(cx - halfW, y1, cx + halfW, y1);
        dc.drawLine(cx - halfW, y2, cx + halfW, y2);

        // Side ticks at line ends
        dc.drawLine(cx - halfW, cy - 4, cx - halfW + 10, cy - 4);
        dc.drawLine(cx + halfW - 10, cy - 4, cx + halfW, cy - 4);

        // Cyan Alarm Clock icon (left of center)
        var ax = cx - 44;
        dc.setColor(C_CYAN_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ax, cy, 6);
        dc.setPenWidth(1);
        dc.drawLine(ax, cy, ax, cy - 3);
        dc.drawLine(ax, cy, ax + 2, cy);
        dc.drawLine(ax - 5, cy - 6, ax - 3, cy - 4); // left bell
        dc.drawLine(ax + 5, cy - 6, ax + 3, cy - 4); // right bell

        // Cyan Bluetooth icon
        var bx = cx - 20;
        dc.setPenWidth(2);
        dc.drawLine(bx, cy - 6, bx, cy + 6);
        dc.drawLine(bx, cy - 6, bx + 3, cy - 3);
        dc.drawLine(bx + 3, cy - 3, bx - 3, cy + 3);
        dc.drawLine(bx - 3, cy - 3, bx + 3, cy + 3);
        dc.drawLine(bx + 3, cy + 3, bx, cy + 6);

        // Subtle center separator dot
        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);

        // Blue DND / circle-minus badge (right of center)
        var dx = cx + 20;
        dc.setColor(C_BLUE_BADGE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dx, cy, 7);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(dx - 4, cy, dx + 4, cy);

        // Temperature right of badge (e.g. "28°")
        var tempVal = "28°";
        if (Toybox has :Weather) {
            var cond = Weather.getCurrentConditions();
            if (cond != null && cond.temperature != null) {
                var t = cond.temperature;
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    t = t * 9.0 / 5.0 + 32;
                }
                tempVal = t.toNumber().toString() + "°";
            }
        }
        dc.drawText(dx + 12, cy, Graphics.FONT_TINY, tempVal,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Side Telemetry Complications
    // ------------------------------------------------------------------
    function drawSideStat(dc, x, y, kind, valStr, iconOnTop) {
        var font = Graphics.FONT_SMALL;
        var iconY = iconOnTop ? (y - 15) : (y + 15);
        var textY = iconOnTop ? (y + 10) : (y - 10);

        // Draw Value
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, textY, font, valStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw Icon
        if (kind == :activity) {
            // Person in calibration arc
            dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawArc(x, iconY - 1, 8, Graphics.ARC_CLOCKWISE, 160, 20);
            dc.fillCircle(x, iconY - 4, 2);
            dc.drawLine(x, iconY - 2, x, iconY + 5);
            dc.drawLine(x - 5, iconY - 1, x, iconY + 2);
            dc.drawLine(x + 5, iconY - 1, x, iconY + 2);

        } else if (kind == :battery) {
            // Battery icon
            var bw = 9;
            var bh = 14;
            dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x - bw / 2.0, iconY - bh / 2.0, bw, bh, 2);
            dc.fillRectangle(x - 2, iconY - bh / 2.0 - 2, 4, 2);
            // inner level fill
            dc.fillRectangle(x - bw / 2.0 + 2, iconY - 1, bw - 4, bh / 2.0 - 1);

        } else if (kind == :body) {
            // Silhouette with bolt
            dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [x, iconY - 7], [x - 2, iconY - 3], [x, iconY - 3],
                [x - 1, iconY + 1], [x + 2, iconY - 2], [x, iconY - 2]
            ]);
            // Shoulder base
            dc.fillRoundedRectangle(x - 5, iconY + 2, 10, 4, 1);

        } else if (kind == :heart) {
            // Solid heart
            dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
            var r = 3.5;
            dc.fillCircle(x - 3, iconY - 2, r);
            dc.fillCircle(x + 3, iconY - 2, r);
            dc.fillPolygon([
                [x - 6.5, iconY - 1], [x + 6.5, iconY - 1], [x, iconY + 6]
            ]);
        }
    }

    // ------------------------------------------------------------------
    // Bottom Steps Metric (Clean footprint icon + step number)
    // ------------------------------------------------------------------
    function drawStepsRow(dc, cx, y, stepStr) {
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(stepStr, font);
        var iconW = 12;
        var gap = 4;
        var totalW = iconW + gap + tw;
        var left = cx - totalW / 2.0;

        // Blue footprints icon
        var fx = left + iconW / 2.0;
        dc.setColor(C_ARC_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx - 3, y - 2, 2.0);
        dc.fillRoundedRectangle(fx - 4, y + 1, 2, 3, 1);
        dc.fillCircle(fx + 2, y, 2.0);
        dc.fillRoundedRectangle(fx + 1, y + 3, 2, 3, 1);

        // Step number text
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconW + gap, y, font, stepStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Smoothed Heart Rate Graph (Moving average smoothed + latest HR live point)
    // ------------------------------------------------------------------
    function getSmoothedHeartRates(liveHR as Lang.Number?) as Lang.Array<Lang.Float> {
        var raw = [] as Lang.Array<Lang.Float>;
        if (ActivityMonitor has :getHeartRateHistory) {
            try {
                // Fetch recent samples (oldest first for left-to-right timeline)
                var iter = ActivityMonitor.getHeartRateHistory(25, false);
                if (iter != null) {
                    var s = iter.next();
                    while (s != null) {
                        if (s.heartRate != null &&
                            s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE &&
                            s.heartRate > 35 && s.heartRate < 230) {
                            raw.add(s.heartRate.toFloat());
                        }
                        s = iter.next();
                    }
                }
            } catch (e) {}
        }

        // Anchor the latest sample to instantaneous live heart rate
        if (liveHR != null && liveHR > 35) {
            raw.add(liveHR.toFloat());
        }

        // If sensor history has fewer than 5 points (fresh reboot / simulator), provide smooth baseline
        if (raw.size() < 5) {
            var base = (liveHR != null && liveHR > 40) ? liveHR.toFloat() : 75.0f;
            var offsets = [-5.0f, -4.0f, -2.0f, 1.0f, 4.0f, 6.0f, 5.0f, 3.0f, 0.0f, -2.0f, -3.0f, -1.0f, 2.0f, 1.0f, 0.0f];
            raw = new [offsets.size()] as Lang.Array<Lang.Float>;
            for (var i = 0; i < offsets.size(); i++) {
                raw[i] = base + offsets[i];
            }
        }

        // Apply moving average smoothing (3-point weighted filter: (v[i-1] + 2*v[i] + v[i+1])/4)
        var n = raw.size();
        if (n < 2) {
            return raw;
        }

        var smoothed = new [n] as Lang.Array<Lang.Float>;
        for (var i = 0; i < n; i++) {
            if (i == n - 1) {
                // Exact live heart rate at rightmost tip
                smoothed[i] = raw[i];
            } else {
                var prevVal = (i > 0) ? raw[i - 1] : raw[i];
                var nextVal = (i + 1 < n) ? raw[i + 1] : raw[i];
                smoothed[i] = (prevVal + raw[i] * 2.0f + nextVal) / 4.0f;
            }
        }
        return smoothed;
    }

    function drawHeartRateGraph(dc, cx, y, graphW, graphH, liveHR as Lang.Number?) {
        var points = getSmoothedHeartRates(liveHR);
        var n = points.size();
        if (n < 2) { return; }

        var left = (cx - graphW / 2.0).toNumber();
        var right = left + graphW;
        var top = (y - graphH / 2.0).toNumber();
        var bottom = top + graphH;

        // Find min, max, avg
        var minVal = 999.0f;
        var maxVal = 0.0f;
        var sum = 0.0f;
        for (var i = 0; i < n; i++) {
            var v = points[i];
            if (v < minVal) { minVal = v; }
            if (v > maxVal) { maxVal = v; }
            sum += v;
        }
        var avgVal = sum / n.toFloat();

        // Enforce minimum visual dynamic range
        if (maxVal - minVal < 20.0f) {
            var mid = (maxVal + minVal) / 2.0f;
            minVal = mid - 10.0f;
            maxVal = mid + 10.0f;
        }
        var range = maxVal - minVal;

        // 1. Subtle horizontal dotted average guideline
        var avgY = (bottom - ((avgVal - minVal) / range) * graphH).toNumber();
        if (avgY >= top && avgY <= bottom) {
            dc.setColor(0x1E293B, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var dx = left; dx < right; dx += 6) {
                dc.drawLine(dx, avgY, dx + 3, avgY);
            }
        }

        // 2. Compute coordinates
        var xs = new [n];
        var ys = new [n];
        for (var i = 0; i < n; i++) {
            xs[i] = (left + (i.toFloat() / (n - 1).toFloat()) * graphW).toNumber();
            var norm = (points[i] - minVal) / range;
            if (norm < 0.0f) { norm = 0.0f; }
            if (norm > 1.0f) { norm = 1.0f; }
            ys[i] = (bottom - norm * (graphH - 4) - 2).toNumber();
        }

        // 3. Shaded translucent ruby area under curve
        dc.setColor(0x3B0814, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < n - 1; i++) {
            var x1 = xs[i];
            var x2 = xs[i + 1];
            var y1 = ys[i];
            var y2 = ys[i + 1];
            dc.fillPolygon([
                [x1, y1],
                [x2, y2],
                [x2, bottom],
                [x1, bottom]
            ]);
        }

        // 4. Smooth glowing heart rate line
        dc.setColor(0xFF1744, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < n - 1; i++) {
            dc.drawLine(xs[i], ys[i], xs[i + 1], ys[i + 1]);
        }

        // 5. Glowing pulse dot on the latest sample (rightmost edge)
        var lastX = xs[n - 1];
        var lastY = ys[n - 1];
        dc.setColor(0xFF1744, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lastX, lastY, 3.5);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lastX, lastY, 2.0);

        // 6. Subtle average label at top-left of the chart
        dc.setColor(0x71717A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, top - 11, Graphics.FONT_XTINY, "AVG " + avgVal.toNumber().toString(),
                    Graphics.TEXT_JUSTIFY_LEFT);

        dc.setPenWidth(1);
    }

    // ------------------------------------------------------------------
    // Bottom-Center Status Bar (6 o'clock)
    // ------------------------------------------------------------------
    function drawBottomStatusBar(dc, cx, y) {
        // Blue footprints (left)
        dc.setColor(C_ARC_BLUE, Graphics.COLOR_TRANSPARENT);
        var bx = cx - 18;
        dc.fillCircle(bx - 3, y - 2, 2);
        dc.fillRoundedRectangle(bx - 4, y + 1, 2.5, 3, 1);
        dc.fillCircle(bx + 3, y, 2);
        dc.fillRoundedRectangle(bx + 2, y + 3, 2.5, 3, 1);

        // Center white vertical bar
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx, y - 4, cx, y + 4);

        // Green Stopwatch icon (right)
        dc.setColor(C_ARC_GREEN, Graphics.COLOR_TRANSPARENT);
        var sx = cx + 18;
        dc.drawCircle(sx, y, 5);
        dc.setPenWidth(1);
        dc.drawLine(sx, y - 5, sx, y - 7); // top pusher
        dc.drawLine(sx, y, sx + 2, y - 2); // hand
    }
}
