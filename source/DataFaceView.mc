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

    function initialize() {
        WatchFace.initialize();
        findComplications();
    }

    function findComplications() {
        if (!(Toybox has :Complications)) {
            return;
        }
        try {
            var list = Complications.getComplications();
            var items = [];
            if (list instanceof Lang.Array) {
                items = list;
            } else if (list != null) {
                var c = list.next();
                while (c != null) {
                    items.add(c);
                    c = list.next();
                }
            }

            for (var i = 0; i < items.size(); i++) {
                var comp = items[i];
                var label = "";
                if (comp.longLabel != null) { label = label + comp.longLabel; }
                if (comp.shortLabel != null) { label = label + " " + comp.shortLabel; }
                label = label.toLower();

                var cType = null;
                if (comp has :getType) {
                    cType = comp.getType();
                }

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
            }

            if (_sleepId != null) { Complications.subscribeToUpdates(_sleepId); }
            if (_readyId != null) { Complications.subscribeToUpdates(_readyId); }
            if (_recoverId != null) { Complications.subscribeToUpdates(_recoverId); }
            if (_hrId != null) { Complications.subscribeToUpdates(_hrId); }
            if (_bodyBattId != null) { Complications.subscribeToUpdates(_bodyBattId); }
            if (_stressId != null) { Complications.subscribeToUpdates(_stressId); }
            if (_stepsId != null) { Complications.subscribeToUpdates(_stepsId); }

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

        // 1. Top-Left: Readiness / Stress
        if (x < _cx - 30 && y >= _hourTop && y <= _y1) {
            System.println("[Touch] Top-Left tapped -> launching Readiness/Stress detail");
            if (_readyId != null && launchComplication(_readyId)) { return true; }
            if (_stressId != null && launchComplication(_stressId)) { return true; }
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

        // 5. Center Divider Bar
        if (y >= _y1 - 8 && y <= _y2 + 8) {
            if (x < _cx - 40) {
                System.println("[Touch] Alarms icon tapped");
                // Fall back to calendar or timer if alarm complication is not direct
                if (_calendarId != null && launchComplication(_calendarId)) { return true; }
            } else if (x > _cx + 40) {
                System.println("[Touch] Weather/Temp tapped -> launching Weather detail");
                if (_weatherId != null && launchComplication(_weatherId)) { return true; }
            } else {
                System.println("[Touch] Date tapped -> launching Calendar/Agenda detail");
                if (_calendarId != null && launchComplication(_calendarId)) { return true; }
            }
            return true;
        }

        // 6. Top Header (above hours): Status bar and Distance
        if (y < _hourTop) {
            if (y < _h * 0.16) {
                System.println("[Touch] Top Status Bar tapped -> launching Recovery/Sleep detail");
                if (_recoverId != null && launchComplication(_recoverId)) { return true; }
                if (_sleepId != null && launchComplication(_sleepId)) { return true; }
            } else {
                System.println("[Touch] Distance row tapped -> launching Distance/Activity detail");
                if (_distanceId != null && launchComplication(_distanceId)) { return true; }
            }
            return true;
        }

        // 7. Bottom Footer (below minutes): Steps and Activity
        if (y > _minBottom) {
            System.println("[Touch] Steps row tapped -> launching Steps detail");
            if (_stepsId != null && launchComplication(_stepsId)) { return true; }
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
    function fmtNum(v) {
        if (v == null) { return "--"; }
        if (v instanceof Lang.Number || v instanceof Lang.Float ||
            v instanceof Lang.Long || v instanceof Lang.Double) {
            return v.toNumber().toString();
        }
        return v.toString();
    }

    function latestSensor(kind) {
        if (!(Toybox has :SensorHistory)) { return null; }
        var it = null;
        var opts = { :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST };
        if (kind == :bodyBattery && (SensorHistory has :getBodyBatteryHistory)) {
            it = SensorHistory.getBodyBatteryHistory(opts);
        } else if (kind == :stress && (SensorHistory has :getStressHistory)) {
            it = SensorHistory.getStressHistory(opts);
        }
        if (it == null) { return null; }
        var s = it.next();
        if (s != null && s.data != null) { return s.data.toNumber(); }
        return null;
    }

    // Stress: tries sources from most→least real-time
    // 1. ActivityMonitor.Info.stressScore  (API 4.1.0+, live)
    // 2. Complications value               (pushed on change)
    // 3. SensorHistory newest sample       (3-4 min cadence, last resort)
    function stressScore() as Lang.Number? {
        // Source 1: live stressScore on ActivityMonitor.Info (API 4.1+)
        if (ActivityMonitor has :getInfo) {
            var am = ActivityMonitor.getInfo();
            if (am != null && (am has :stressScore) && am.stressScore != null) {
                var s = am.stressScore;
                if (s >= 0 && s <= 100) { return s; }
            }
        }
        // Source 2: complication value (subscribed → pushed on each measurement)
        var cv = compValue(_stressId);
        if (cv != null) {
            var s = cv.toNumber();
            if (s >= 0 && s <= 100) { return s; }
        }
        // Source 3: SensorHistory newest sample (slowest cadence, fallback)
        return latestSensor(:stress);
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
        var stepGoal = (am != null && am.stepGoal != null && am.stepGoal > 0) ? am.stepGoal : 10000;
        var batt = System.getSystemStats().battery;
        var bb = latestSensor(:bodyBattery);
        if (bb == null) { bb = 78; } // fallback demo default
        var hrv = heartRate();
        if (hrv == null) { hrv = 80; } // fallback demo default
        // Stress: multi-source (live ActivityMonitor > complication > SensorHistory)
        var st = stressScore();
        // Readiness: prefer dedicated complication, fall back to stress, then null (shows --)
        var ready = compValue(_readyId);
        if (ready == null) { ready = st; }

        // 1. Outer Bezel Ticks & Cardinal Accents
        drawBezelAccents(dc, cx, cy, w * 0.47);

        // 2. The 4 Colored Segmented Progress Arcs
        var battPct = (batt != null) ? batt / 100.0 : 0.78;
        var bbPct = (bb != null) ? bb / 100.0 : 0.78;
        var stepPct = steps.toFloat() / stepGoal.toFloat();
        if (stepPct > 1.0) { stepPct = 1.0; }
        var readyPct = (ready != null) ? ready / 100.0 : 0.85;

        var arcR = w * 0.44;
        // Top-Left: Red arc (Readiness/Stress)
        drawSegmentedArc(dc, cx, cy, arcR, 122.0, 162.0, 14, readyPct, C_ARC_RED, C_ARC_RED);
        // Top-Right: Yellow-Orange gradient arc (Battery)
        drawSegmentedArc(dc, cx, cy, arcR, 18.0, 58.0, 14, battPct, C_ARC_YELLOW, C_ARC_ORANGE);
        // Bottom-Left: Blue arc (Body Battery)
        drawSegmentedArc(dc, cx, cy, arcR, 198.0, 238.0, 14, bbPct, C_ARC_BLUE, C_ARC_BLUE);
        // Bottom-Right: Green arc (Step Goal)
        drawSegmentedArc(dc, cx, cy, arcR, 302.0, 342.0, 14, stepPct, C_ARC_GREEN, C_ARC_GREEN);

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

        // Distance row: above hourTop
        var distY = hourTop - (h * 0.045);

        // Top status bar: above distY
        var topStatusY = distY - (h * 0.065);

        // Steps row: below minBottom
        var stepsY = minBottom + (h * 0.048);

        // Bottom status bar: below stepsY
        var botStatusY = stepsY + (h * 0.065);

        // 4. Top-Center Status Bar (12 o'clock)
        drawTopStatusBar(dc, cx, topStatusY);

        // 5. Distance / Swimmer Metric (Above Hours)
        var distStr = "0.0M";
        if (am != null && (am has :distance) && am.distance != null) {
            var isMetric = (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC);
            if (isMetric) {
                distStr = (am.distance / 100000.0).format("%.1f") + "KM";
            } else {
                distStr = (am.distance / 160934.4).format("%.1f") + "M";
            }
        }
        drawDistanceRow(dc, cx, distY, distStr);

        // 6. Center Stacked Time with True Gradient (Zero overlap)
        drawGradientText(dc, cx, hourY, fontTime, hStr, C_HOUR_TOP, C_HOUR_BOT);
        drawGradientText(dc, cx, minY, fontTime, mStr, C_MIN_TOP, C_MIN_BOT);

        // 7. Horizontal Divider Bar & Date Row
        drawCenterDividerBar(dc, cx, cy, w * 0.72);

        // 8. Four Side Telemetry Complications
        // Positioned at w * 0.20 and w * 0.80 to leave generous horizontal margin from digits
        // Top-Left: Readiness (Icon on Top, Number Below)
        drawSideStat(dc, w * 0.20, hourY, :activity, fmtNum(ready), true);
        // Top-Right: Battery (Icon on Top, Number Below)
        drawSideStat(dc, w * 0.80, hourY, :battery, fmtNum(batt), true);
        // Bottom-Left: Body Battery (Number on Top, Icon Below)
        drawSideStat(dc, w * 0.20, minY, :body, fmtNum(bb), false);
        // Bottom-Right: Heart Rate (Number on Top, Icon Below)
        drawSideStat(dc, w * 0.80, minY, :heart, fmtNum(hrv), false);

        // 9. Bottom Steps Bar Graph + Count
        drawStepsBarGraph(dc, cx, stepsY, steps, stepGoal);

        // 10. Bottom-Center Status Bar (6 o'clock)
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
    // Top Status Bar (Red trend, Moon Phase, Yellow Bolt)
    // ------------------------------------------------------------------
    function drawTopStatusBar(dc, cx, y) {
        // Red Trend arrow (zigzag)
        dc.setColor(C_ARC_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var tx = cx - 24;
        dc.drawLine(tx - 6, y + 4, tx - 2, y);
        dc.drawLine(tx - 2, y, tx + 1, y + 3);
        dc.drawLine(tx + 1, y + 3, tx + 6, y - 4);
        dc.drawLine(tx + 2, y - 4, tx + 6, y - 4);
        dc.drawLine(tx + 6, y - 4, tx + 6, y);

        // Moon Phase (half moon: left half white, right half dark)
        var mr = 7;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, y, mr);
        dc.setColor(C_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx, y - mr, mr + 2, mr * 2 + 2);
        dc.setColor(0x8E9BAE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, y, mr);

        // Yellow Lightning Bolt
        dc.setColor(C_ARC_YELLOW, Graphics.COLOR_TRANSPARENT);
        var bx = cx + 24;
        dc.fillPolygon([
            [bx + 1, y - 7], [bx - 4, y], [bx - 1, y],
            [bx - 2, y + 7], [bx + 4, y - 1], [bx + 1, y - 1]
        ]);
    }

    // ------------------------------------------------------------------
    // Swimmer & Distance Row
    // ------------------------------------------------------------------
    function drawDistanceRow(dc, cx, y, distStr) {
        var font = Graphics.FONT_TINY;
        var tw = dc.getTextWidthInPixels(distStr, font);
        var iconW = 16;
        var gap = 5;
        var totalW = iconW + gap + tw;
        var left = cx - totalW / 2.0;

        // Swimmer icon
        var ix = left + iconW / 2.0;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ix - 1, y - 4, 2.5); // head
        dc.setPenWidth(2);
        dc.drawLine(ix - 5, y - 1, ix + 5, y - 3); // torso & arm
        // Water wave underneath
        dc.drawLine(ix - 7, y + 3, ix - 3, y + 1);
        dc.drawLine(ix - 3, y + 1, ix + 2, y + 4);
        dc.drawLine(ix + 2, y + 4, ix + 6, y + 2);

        // Distance text
        dc.drawText(left + iconW + gap, y, font, distStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------
    // Horizontal Divider Bar & Date Row
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

        // Cyan Alarm Clock icon
        var ax = cx - halfW + 28;
        dc.setColor(C_CYAN_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ax, cy, 6);
        dc.setPenWidth(1);
        dc.drawLine(ax, cy, ax, cy - 3);
        dc.drawLine(ax, cy, ax + 2, cy);
        dc.drawLine(ax - 5, cy - 6, ax - 3, cy - 4); // left bell
        dc.drawLine(ax + 5, cy - 6, ax + 3, cy - 4); // right bell

        // Cyan Bluetooth icon
        var bx = ax + 18;
        dc.setPenWidth(2);
        dc.drawLine(bx, cy - 6, bx, cy + 6);
        dc.drawLine(bx, cy - 6, bx + 3, cy - 3);
        dc.drawLine(bx + 3, cy - 3, bx - 3, cy + 3);
        dc.drawLine(bx - 3, cy - 3, bx + 3, cy + 3);
        dc.drawLine(bx + 3, cy + 3, bx, cy + 6);

        // Date String (e.g. "Jeu 02 Jan." or English equivalent)
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = info.day_of_week + " " + info.day.format("%02d") + " " + info.month + ".";
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 6, cy, Graphics.FONT_TINY, dateStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Blue DND / circle-minus badge
        var dx = cx + halfW - 32;
        dc.setColor(C_BLUE_BADGE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dx, cy, 7);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(dx - 4, cy, dx + 4, cy);

        // Number right of badge (e.g. "28" temperature or date day)
        var tempVal = info.day.toString();
        if (Toybox has :Weather) {
            var cond = Weather.getCurrentConditions();
            if (cond != null && cond.temperature != null) {
                var t = cond.temperature;
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    t = t * 9.0 / 5.0 + 32;
                }
                tempVal = t.toNumber().toString();
            }
        }
        dc.drawText(dx + 13, cy, Graphics.FONT_TINY, tempVal,
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
    // Bottom Steps Bar Graph (7-day history or hourly segments fallback)
    // ------------------------------------------------------------------
    function drawStepsBarGraph(dc, cx, y, todaySteps, stepGoal) {
        // --- Collect 7-day step history ---
        var barValues = new [7];
        var barGoals  = new [7];
        var gotHistory = false;

        if (ActivityMonitor has :getDailyHistory) {
            try {
                var hist = ActivityMonitor.getDailyHistory();
                if (hist != null) {
                    var dayInfo = hist.next();
                    var idx = 6; // fill from right (today = index 6)
                    while (dayInfo != null && idx >= 0) {
                        var s = (dayInfo has :steps && dayInfo.steps != null) ? dayInfo.steps : 0;
                        var g = (dayInfo has :stepGoal && dayInfo.stepGoal != null && dayInfo.stepGoal > 0) ? dayInfo.stepGoal : stepGoal;
                        barValues[idx] = s;
                        barGoals[idx]  = g;
                        idx--;
                        dayInfo = hist.next();
                    }
                    // Fill any remaining slots with 0
                    while (idx >= 0) {
                        barValues[idx] = 0;
                        barGoals[idx]  = stepGoal;
                        idx--;
                    }
                    gotHistory = true;
                }
            } catch (ex) {
                gotHistory = false;
            }
        }

        // Fallback / Simulator demo data
        if (!gotHistory) {
            // Use realistic simulated 7-day values so the graph is visible in the simulator.
            // Pct of stepGoal per day: Mo Tu We Th Fr Sa To(today)
            var simPct = [0.82f, 1.05f, 0.63f, 0.90f, 0.45f, 1.10f, 0.0f];
            // Replace today's slot with live steps / goal ratio
            simPct[6] = todaySteps.toFloat() / stepGoal.toFloat();
            if (simPct[6] < 0.08f && todaySteps == 0) { simPct[6] = 0.38f; } // demo fill if no live data
            for (var i = 0; i < 7; i++) {
                var p = simPct[i];
                if (p > 1.0f) { p = 1.0f; }
                barValues[i] = (stepGoal * p).toNumber();
                barGoals[i]  = stepGoal;
            }
        }

        // --- Layout ---
        var NUM_BARS    = 7;
        var BAR_W       = 10;
        var BAR_GAP     = 4;
        var MAX_BAR_H   = 24;
        var totalW      = NUM_BARS * BAR_W + (NUM_BARS - 1) * BAR_GAP;
        var barLeft     = (cx - totalW / 2.0).toNumber();
        var barBaseY    = (y + MAX_BAR_H / 2.0).toNumber(); // baseline (bottom of bars)

        // --- Step count label above bars ---
        var font = Graphics.FONT_TINY;
        var stepStr = todaySteps.toString();

        // Footprint icon + count centered above the bar graph
        var labelY = (y - MAX_BAR_H / 2.0 - 10).toNumber();
        var tw = dc.getTextWidthInPixels(stepStr, font);
        var iconW = 13;
        var gap = 4;
        var labelLeft = (cx - (iconW + gap + tw) / 2.0).toNumber();

        // Blue footprint icon
        dc.setColor(C_ARC_BLUE, Graphics.COLOR_TRANSPARENT);
        var fx = labelLeft + iconW / 2;
        dc.fillCircle(fx - 3, labelY - 3, 2.0);
        dc.fillRoundedRectangle(fx - 4, labelY, 2, 3, 1);
        dc.fillCircle(fx + 2, labelY - 1, 2.0);
        dc.fillRoundedRectangle(fx + 1, labelY + 2, 2, 3, 1);

        // Step count text
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelLeft + iconW + gap, labelY, font, stepStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- Draw bars ---
        for (var i = 0; i < NUM_BARS; i++) {
            var bx = barLeft + i * (BAR_W + BAR_GAP);
            var goal = (barGoals[i] > 0) ? barGoals[i] : stepGoal;
            var pct  = barValues[i].toFloat() / goal.toFloat();
            if (pct > 1.0) { pct = 1.0; }
            if (pct < 0.0) { pct = 0.0; }

            var fillH = (pct * MAX_BAR_H).toNumber();
            if (fillH < 1 && barValues[i] > 0) { fillH = 1; }

            var isToday = (i == NUM_BARS - 1);

            // Background (empty) bar track
            dc.setColor(C_ARC_DARK, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, barBaseY - MAX_BAR_H, BAR_W, MAX_BAR_H, 2);

            // Filled portion
            if (fillH > 0) {
                var col = isToday ? C_ARC_GREEN : blendColor(C_ARC_GREEN, 0x007A40, 0.45);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(bx, barBaseY - fillH, BAR_W, fillH, 2);
            }

            // Today's bar: white outline highlight
            if (isToday) {
                dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                dc.drawRoundedRectangle(bx, barBaseY - MAX_BAR_H, BAR_W, MAX_BAR_H, 2);
            }
        }

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
