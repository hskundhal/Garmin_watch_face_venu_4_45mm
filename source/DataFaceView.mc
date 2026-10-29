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
const C_BG       = 0x000000;
const C_TIME_H   = 0xFFFFFF;
const C_TIME_M   = 0x2EE6FF;
const C_DATE     = 0xBFC8D6;
const C_HR       = 0xFF4D5E;
const C_BODYBATT = 0x2EA8FF;
const C_STRESS   = 0xFFA23A;
const C_SUN      = 0xFFD23F;
const C_CLOUD    = 0xA9C4E8;
const C_RAIN     = 0x4DA3FF;
const C_UV       = 0xC77DFF;
const C_STEPS    = 0x3CE68A;
const C_SLEEP    = 0x8F7CFF;
const C_RECOVER  = 0x2EE6D6;
const C_READY    = 0xB6F23A;

class DataFaceView extends WatchUi.WatchFace {

    hidden var _lowPower = false;
    hidden var _sleepId = null;
    hidden var _readyId = null;
    hidden var _recoverId = null;

    function initialize() {
        WatchFace.initialize();
        findComplications();
    }

    // ------------------------------------------------------------------
    // Complications: used for Sleep Score, Training Readiness (and a
    // fallback for Recovery Time). Matched by label text so we don't depend
    // on constants that vary between API levels. Labels are printed to the
    // console so you can see what your watch exposes.
    // ------------------------------------------------------------------
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
                System.println("[complication] " + label);

                if (_sleepId == null && label.find("sleep") != null && label.find("score") != null) {
                    _sleepId = comp.complicationId;
                } else if (_readyId == null && label.find("readiness") != null) {
                    _readyId = comp.complicationId;
                } else if (_recoverId == null && label.find("recover") != null) {
                    _recoverId = comp.complicationId;
                }
            }

            if (_sleepId != null) { Complications.subscribeToUpdates(_sleepId); }
            if (_readyId != null) { Complications.subscribeToUpdates(_readyId); }
            if (_recoverId != null) { Complications.subscribeToUpdates(_recoverId); }
            Complications.registerComplicationChangeCallback(self.method(:onComplicationChanged));
        } catch (ex) {
            System.println("Complications unavailable: " + ex.getErrorMessage());
        }
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
    // Data helpers
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

    function compactSteps(steps) {
        if (steps == null) { return "--"; }
        if (steps >= 1000) { return (steps / 1000.0).format("%.1f") + "k"; }
        return steps.toString();
    }

    // ------------------------------------------------------------------
    // Layout
    // ------------------------------------------------------------------
    function onEnterSleep() {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(C_BG, C_BG);
        dc.clear();

        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;
        var hr = clock.hour;
        var ampm = "";
        if (!is24) {
            ampm = (hr >= 12) ? "PM" : "AM";
            hr = hr % 12;
            if (hr == 0) { hr = 12; }
        }
        var hStr = is24 ? hr.format("%02d") : hr.toString();
        var mStr = clock.min.format("%02d");

        if (_lowPower) {
            // AMOLED burn-in friendly: dim time only, nudged each minute.
            var nudge = (clock.min % 3) - 1;
            drawTime(dc, cx + nudge * 2, h * 0.5 + nudge * 2, hStr, mStr, "", 0x808080, 0x808080);
            return;
        }

        var iconS = h * 0.05;
        var fontMain = Graphics.FONT_TINY;
        var fontSmall = Graphics.FONT_XTINY;

        // ---- Row A: date (left) + battery (right) ----------------------
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = (info.day_of_week + " " + info.day.toString() + " " + info.month).toUpper();
        dc.setColor(C_DATE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.36, h * 0.105, fontSmall, dateStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var batt = System.getSystemStats().battery;
        var battColor = (batt > 40) ? C_STEPS : ((batt > 20) ? C_SUN : C_HR);
        drawItem(dc, :battery, w * 0.69, h * 0.105, iconS * 0.8, battColor,
                 batt.toNumber().toString() + "%", fontSmall, batt);

        // ---- Row B: weather + UV ---------------------------------------
        var wxKind = :cloud;
        var wxColor = C_CLOUD;
        var tempStr = "--";
        var uvStr = "--";
        if (Toybox has :Weather) {
            var cond = Weather.getCurrentConditions();
            if (cond != null) {
                if (cond.temperature != null) {
                    var t = cond.temperature;
                    var units = System.getDeviceSettings().temperatureUnits;
                    if (units == System.UNIT_STATUTE) { t = t * 9.0 / 5.0 + 32; }
                    tempStr = t.toNumber().toString() + "°";
                }
                if ((cond has :uvIndex) && cond.uvIndex != null) {
                    uvStr = cond.uvIndex.toNumber().toString();
                }
                var c = cond.condition;
                if (c != null) {
                    if (c == 0 || c == 1 || c == 22 || c == 23 || c == 40) {
                        wxKind = :sun; wxColor = C_SUN;
                    } else if (c == 3 || c == 4 || c == 6 || c == 11 || c == 12 || c == 14 ||
                               c == 15 || c == 16 || c == 17 || c == 24 || c == 25 || c == 26) {
                        wxKind = :drop; wxColor = C_RAIN;
                    }
                }
            }
        }
        drawItem(dc, wxKind, w * 0.37, h * 0.225, iconS, wxColor, tempStr, fontMain, null);
        drawItem(dc, :sun, w * 0.65, h * 0.225, iconS, C_UV, "UV " + uvStr, fontMain, null);

        // ---- Time (centre) ---------------------------------------------
        drawTime(dc, cx, h * 0.425, hStr, mStr, ampm, C_TIME_H, C_TIME_M);

        // ---- Row C: heart rate, body battery, stress -------------------
        var hrv = heartRate();
        var bb = latestSensor(:bodyBattery);
        var st = latestSensor(:stress);
        drawItem(dc, :heart, w * 0.25, h * 0.63, iconS, C_HR, fmtNum(hrv), fontMain, null);
        drawItem(dc, :bolt, w * 0.50, h * 0.63, iconS, C_BODYBATT, fmtNum(bb), fontMain, null);
        drawItem(dc, :stress, w * 0.75, h * 0.63, iconS, C_STRESS, fmtNum(st), fontMain, null);

        // ---- Row D: steps + sleep score --------------------------------
        var am = ActivityMonitor.getInfo();
        var steps = (am != null) ? am.steps : null;
        drawItem(dc, :steps, w * 0.34, h * 0.75, iconS, C_STEPS, compactSteps(steps), fontMain, null);
        drawItem(dc, :moon, w * 0.66, h * 0.75, iconS, C_SLEEP, fmtNum(compValue(_sleepId)), fontMain, null);

        // ---- Row E: recovery hours + training readiness ----------------
        var rec = null;
        if (am != null && (am has :timeToRecovery)) { rec = am.timeToRecovery; }
        if (rec == null) { rec = compValue(_recoverId); }
        var recStr = (rec == null) ? "--" : fmtNum(rec) + "h";
        drawItem(dc, :clock, w * 0.36, h * 0.87, iconS, C_RECOVER, recStr, fontMain, null);
        drawItem(dc, :gauge, w * 0.64, h * 0.87, iconS, C_READY, fmtNum(compValue(_readyId)), fontMain, null);
    }

    // ------------------------------------------------------------------
    // Drawing primitives
    // ------------------------------------------------------------------
    function drawTime(dc, cx, cy, hStr, mStr, ampm, colH, colM) {
        var font = Graphics.FONT_NUMBER_HOT;
        var wh = dc.getTextWidthInPixels(hStr, font);
        var wc = dc.getTextWidthInPixels(":", font);
        var wm = dc.getTextWidthInPixels(mStr, font);
        var left = cx - (wh + wc + wm) / 2.0;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(colH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, cy, font, hStr, just);
        dc.setColor(0x8A94A6, Graphics.COLOR_TRANSPARENT);
        if (colH != 0x808080) {
            dc.setColor(C_DATE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(left + wh, cy, font, ":", just);
        dc.setColor(colM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + wh + wc, cy, font, mStr, just);

        if (!ampm.equals("")) {
            dc.setColor(C_DATE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + wh + wc + wm + 4, cy + dc.getFontHeight(font) * 0.22,
                        Graphics.FONT_XTINY, ampm, just);
        }
    }

    // Icon + value, centred as a group on (cx, cy).
    function drawItem(dc, kind, cx, cy, s, color, text, font, val) {
        var gap = s * 0.3;
        var iconW = s * 1.2;
        var tw = dc.getTextWidthInPixels(text, font);
        var left = cx - (iconW + gap + tw) / 2.0;
        drawIcon(dc, kind, left + iconW / 2.0, cy, s, color, val);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconW + gap, cy, font, text,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawIcon(dc, kind, x, y, s, color, val) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        if (kind == :heart) {
            var r = s * 0.27;
            dc.fillCircle(x - s * 0.23, y - s * 0.15, r);
            dc.fillCircle(x + s * 0.23, y - s * 0.15, r);
            dc.fillPolygon([[x - s * 0.49, y - s * 0.05], [x + s * 0.49, y - s * 0.05], [x, y + s * 0.5]]);

        } else if (kind == :battery) {
            var bw = s * 1.1;
            var bh = s * 0.6;
            var l = x - bw / 2.0;
            var t = y - bh / 2.0;
            dc.drawRectangle(l, t, bw, bh);
            dc.fillRectangle(l + bw, y - bh * 0.2, 2, bh * 0.4);
            var pct = (val == null) ? 0 : val;
            dc.fillRectangle(l + 2, t + 2, (bw - 4) * pct / 100.0, bh - 4);

        } else if (kind == :bolt) {
            dc.fillPolygon([
                [x + s * 0.12, y - s * 0.5], [x - s * 0.3, y + s * 0.06], [x - s * 0.02, y + s * 0.06],
                [x - s * 0.12, y + s * 0.5], [x + s * 0.3, y - s * 0.1], [x + s * 0.02, y - s * 0.1]
            ]);

        } else if (kind == :stress) {
            dc.drawLine(x - s * 0.5, y, x - s * 0.25, y - s * 0.35);
            dc.drawLine(x - s * 0.25, y - s * 0.35, x, y + s * 0.35);
            dc.drawLine(x, y + s * 0.35, x + s * 0.25, y - s * 0.35);
            dc.drawLine(x + s * 0.25, y - s * 0.35, x + s * 0.5, y);

        } else if (kind == :sun) {
            dc.fillCircle(x, y, s * 0.2);
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4.0;
                var ca = Math.cos(a);
                var sa = Math.sin(a);
                dc.drawLine(x + ca * s * 0.32, y + sa * s * 0.32, x + ca * s * 0.5, y + sa * s * 0.5);
            }

        } else if (kind == :cloud) {
            dc.fillCircle(x - s * 0.2, y + s * 0.08, s * 0.2);
            dc.fillCircle(x + s * 0.02, y - s * 0.1, s * 0.26);
            dc.fillCircle(x + s * 0.26, y + s * 0.1, s * 0.18);
            dc.fillRectangle(x - s * 0.2, y + s * 0.08, s * 0.46, s * 0.2);

        } else if (kind == :drop) {
            dc.fillCircle(x, y + s * 0.15, s * 0.26);
            dc.fillPolygon([[x, y - s * 0.5], [x - s * 0.24, y + s * 0.07], [x + s * 0.24, y + s * 0.07]]);

        } else if (kind == :steps) {
            dc.fillCircle(x - s * 0.2, y - s * 0.18, s * 0.2);
            dc.fillCircle(x - s * 0.2, y + s * 0.08, s * 0.1);
            dc.fillCircle(x + s * 0.22, y + s * 0.05, s * 0.2);
            dc.fillCircle(x + s * 0.22, y + s * 0.3, s * 0.1);

        } else if (kind == :moon) {
            dc.fillCircle(x, y, s * 0.42);
            dc.setColor(C_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + s * 0.24, y - s * 0.14, s * 0.36);

        } else if (kind == :clock) {
            dc.drawCircle(x, y, s * 0.45);
            dc.drawLine(x, y, x, y - s * 0.28);
            dc.drawLine(x, y, x + s * 0.2, y + s * 0.1);

        } else if (kind == :gauge) {
            dc.drawArc(x, y + s * 0.2, s * 0.5, Graphics.ARC_CLOCKWISE, 180, 0);
            dc.drawLine(x, y + s * 0.2, x + s * 0.3, y - s * 0.15);
            dc.fillCircle(x, y + s * 0.2, s * 0.09);
        }

        dc.setPenWidth(1);
    }
}
