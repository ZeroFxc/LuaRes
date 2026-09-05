package com.androlua;

import android.accessibilityservice.AccessibilityService;
import android.annotation.SuppressLint;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Path;
import android.hardware.display.VirtualDisplay;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.KeyEvent;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import com.androlua.util.ClickRunnable;
import com.androlua.util.GlobalActionAutomator;
import com.luajava.LuaException;
import com.luajava.LuaFunction;
import com.luajava.LuaTable;
import com.nirenr.Point;
import com.nirenr.screencapture.ScreenCaptureListener;
import com.nirenr.screencapture.ScreenShot;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
@SuppressLint({"NewApi"})
public class LuaAccessibilityService extends AccessibilityService {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static AccessibilityServiceCallbacks f699a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private static LuaAccessibilityService f700b;
    public static LuaFunction onAccessibilityEvent;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private LuaApplication f701c;
    private Map d;
    private HashMap<String, ComponentName> e = new HashMap<>();
    private boolean f;
    private Handler g;
    private GlobalActionAutomator h;
    private ScreenShot i;
    private int j;
    private int k;
    private int l;

    public interface AccessibilityServiceCallbacks {
        void onAccessibilityEvent(LuaAccessibilityService luaAccessibilityService, AccessibilityEvent accessibilityEvent);

        void onConfigurationChanged(LuaAccessibilityService luaAccessibilityService, Configuration configuration);

        void onCreate(LuaAccessibilityService luaAccessibilityService);

        void onDestroy(LuaAccessibilityService luaAccessibilityService);

        void onInterrupt(LuaAccessibilityService luaAccessibilityService);

        boolean onKeyEvent(LuaAccessibilityService luaAccessibilityService, KeyEvent keyEvent);

        void onServiceConnected(LuaAccessibilityService luaAccessibilityService);
    }

    private AccessibilityNodeInfo a(AccessibilityNodeInfo accessibilityNodeInfo) {
        for (AccessibilityNodeInfo parent = accessibilityNodeInfo; parent != null; parent = parent.getParent()) {
            try {
                if (isClickable(parent)) {
                    return parent;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return accessibilityNodeInfo;
    }

    private void a() {
        new AsyncTask<String, String, HashMap<String, ComponentName>>() { // from class: com.androlua.LuaAccessibilityService.8
            @Override // android.os.AsyncTask
            /* JADX INFO: renamed from: a, reason: merged with bridge method [inline-methods] */
            protected HashMap<String, ComponentName> doInBackground(String... strArr) {
                HashMap<String, ComponentName> map = new HashMap<>();
                PackageManager packageManager = LuaAccessibilityService.this.getPackageManager();
                Intent intent = new Intent("android.intent.action.MAIN", (Uri) null);
                intent.addCategory("android.intent.category.DEFAULT");
                List<ResolveInfo> listQueryIntentActivities = packageManager.queryIntentActivities(intent, 0);
                Collections.sort(listQueryIntentActivities, new ResolveInfo.DisplayNameComparator(packageManager));
                int size = listQueryIntentActivities.size();
                for (int i = 0; i < size; i++) {
                    ResolveInfo resolveInfo = listQueryIntentActivities.get(i);
                    CharSequence charSequenceLoadLabel = resolveInfo.loadLabel(packageManager);
                    map.put(charSequenceLoadLabel.toString().toLowerCase(), new ComponentName(resolveInfo.activityInfo.applicationInfo.packageName, resolveInfo.activityInfo.name));
                }
                Intent intent2 = new Intent("android.intent.action.MAIN", (Uri) null);
                intent2.addCategory("android.intent.category.LAUNCHER");
                List<ResolveInfo> listQueryIntentActivities2 = packageManager.queryIntentActivities(intent2, 0);
                Collections.sort(listQueryIntentActivities2, new ResolveInfo.DisplayNameComparator(packageManager));
                int size2 = listQueryIntentActivities2.size();
                for (int i2 = 0; i2 < size2; i2++) {
                    ResolveInfo resolveInfo2 = listQueryIntentActivities2.get(i2);
                    CharSequence charSequenceLoadLabel2 = resolveInfo2.loadLabel(packageManager);
                    map.put(charSequenceLoadLabel2.toString().toLowerCase(), new ComponentName(resolveInfo2.activityInfo.applicationInfo.packageName, resolveInfo2.activityInfo.name));
                }
                return map;
            }

            @Override // android.os.AsyncTask
            /* JADX INFO: renamed from: a, reason: merged with bridge method [inline-methods] */
            protected void onPostExecute(HashMap<String, ComponentName> map) {
                super.onPostExecute(map);
                if (map == null || map.isEmpty()) {
                    return;
                }
                LuaAccessibilityService.this.e = map;
            }
        }.execute(BuildConfig.FLAVOR);
    }

    private void a(AccessibilityNodeInfo accessibilityNodeInfo, ArrayList<String> arrayList) {
        if (accessibilityNodeInfo == null) {
            return;
        }
        getNodeInfoText(accessibilityNodeInfo);
        int childCount = accessibilityNodeInfo.getChildCount();
        if (childCount > 0) {
            for (int i = 0; i < childCount; i++) {
                a(accessibilityNodeInfo.getChild(i), arrayList);
            }
        }
    }

    private void a(AccessibilityNodeInfo accessibilityNodeInfo, ArrayList<String> arrayList, AccessibilityNodeInfo accessibilityNodeInfo2) {
        if (accessibilityNodeInfo == null) {
            return;
        }
        if (!this.f) {
            this.f = accessibilityNodeInfo.equals(accessibilityNodeInfo2);
        }
        String nodeInfoText = getNodeInfoText(accessibilityNodeInfo);
        if (this.f && nodeInfoText != null) {
            arrayList.add(nodeInfoText.toString());
        }
        int childCount = accessibilityNodeInfo.getChildCount();
        if (childCount > 0) {
            for (int i = 0; i < childCount; i++) {
                AccessibilityNodeInfo child = accessibilityNodeInfo.getChild(i);
                if (child != null) {
                    if (!this.f) {
                        this.f = child.equals(accessibilityNodeInfo2);
                    }
                    a(child, arrayList, accessibilityNodeInfo2);
                }
            }
        }
    }

    private void a(String str, LuaException luaException) {
    }

    private void a(List<AccessibilityNodeInfo> list, AccessibilityNodeInfo accessibilityNodeInfo, String str) {
        if (accessibilityNodeInfo == null) {
            return;
        }
        String[] strArrSplit = str.split("\\|");
        CharSequence[] charSequenceArr = {accessibilityNodeInfo.getContentDescription(), accessibilityNodeInfo.getText()};
        for (String str2 : strArrSplit) {
            boolean z = !str2.startsWith("*");
            boolean z2 = !str2.endsWith("*");
            String strSubstring = str2;
            if (!z) {
                strSubstring = str2.substring(1);
            }
            if (!z2) {
                strSubstring = strSubstring.substring(0, strSubstring.length() - 1);
            }
            for (CharSequence charSequence : charSequenceArr) {
                if (charSequence != null) {
                    String strTrim = charSequence.toString().trim();
                    if (!z || !z2) {
                        if (!z) {
                            if (!z2) {
                                if (strTrim.contains(strSubstring)) {
                                    list.add(accessibilityNodeInfo);
                                    break;
                                    break;
                                }
                            } else {
                                if (strTrim.endsWith(strSubstring)) {
                                    list.add(accessibilityNodeInfo);
                                    break;
                                    break;
                                }
                            }
                        } else {
                            if (strTrim.startsWith(strSubstring)) {
                                list.add(accessibilityNodeInfo);
                                break;
                            }
                        }
                    } else {
                        if (strSubstring.equals(strTrim)) {
                            list.add(accessibilityNodeInfo);
                            break;
                            break;
                        }
                    }
                }
            }
        }
        int childCount = accessibilityNodeInfo.getChildCount();
        for (int i = 0; i < childCount; i++) {
            a(list, accessibilityNodeInfo.getChild(i), str);
        }
    }

    private AccessibilityNodeInfo b(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return null;
        }
        if (isListView2(accessibilityNodeInfo)) {
            return accessibilityNodeInfo;
        }
        int childCount = accessibilityNodeInfo.getChildCount();
        for (int i = 0; i < childCount; i++) {
            AccessibilityNodeInfo accessibilityNodeInfoB = b(accessibilityNodeInfo.getChild(i));
            if (accessibilityNodeInfoB != null) {
                return accessibilityNodeInfoB;
            }
        }
        return null;
    }

    private void b() {
        PackageManager packageManager = getPackageManager();
        Intent intent = new Intent("android.intent.action.MAIN", (Uri) null);
        intent.addCategory("android.intent.category.LAUNCHER");
        List<ResolveInfo> listQueryIntentActivities = packageManager.queryIntentActivities(intent, 0);
        Collections.sort(listQueryIntentActivities, new ResolveInfo.DisplayNameComparator(packageManager));
        if (listQueryIntentActivities != null) {
            int size = listQueryIntentActivities.size();
            for (int i = 0; i < size; i++) {
                ResolveInfo resolveInfo = listQueryIntentActivities.get(i);
                CharSequence charSequenceLoadLabel = resolveInfo.loadLabel(packageManager);
                this.e.put(charSequenceLoadLabel.toString().toLowerCase(), new ComponentName(resolveInfo.activityInfo.applicationInfo.packageName, resolveInfo.activityInfo.name));
            }
        }
    }

    private void c() {
        WindowManager windowManager = (WindowManager) getSystemService("window");
        DisplayMetrics displayMetrics = new DisplayMetrics();
        if (windowManager == null) {
            return;
        }
        windowManager.getDefaultDisplay().getRealMetrics(displayMetrics);
        this.j = displayMetrics.densityDpi;
        this.k = displayMetrics.widthPixels;
        this.l = displayMetrics.heightPixels;
    }

    public static LuaAccessibilityService getInstance() {
        return f700b;
    }

    public static void setCallback(AccessibilityServiceCallbacks accessibilityServiceCallbacks) {
        f699a = accessibilityServiceCallbacks;
    }

    public boolean appendCopy() {
        return appendCopy(getText(getFocusView()));
    }

    public boolean appendCopy(CharSequence charSequence) {
        if (charSequence == null) {
            return false;
        }
        ClipboardManager clipboardManager = (ClipboardManager) getSystemService("clipboard");
        CharSequence text = clipboardManager.getText();
        String string = text != null ? text.toString() : BuildConfig.FLAVOR;
        if (string.length() > 1) {
            string = string + "\n";
        }
        clipboardManager.setPrimaryClip(ClipData.newPlainText("label", string + ((Object) charSequence)));
        return true;
    }

    public boolean click(int i, int i2) {
        GlobalActionAutomator globalActionAutomator = this.h;
        if (globalActionAutomator != null) {
            return globalActionAutomator.click(i, i2);
        }
        return false;
    }

    public boolean click(LuaTable luaTable) {
        return new ClickRunnable(this, luaTable).canClick();
    }

    public boolean click(LuaTable luaTable, final LuaFunction luaFunction) {
        return new ClickRunnable(this, luaTable).canClick(new ClickRunnable.ClickCallback() { // from class: com.androlua.LuaAccessibilityService.6
            @Override // com.androlua.util.ClickRunnable.ClickCallback
            public void onDone(boolean z, LuaTable luaTable2, String str, int i) {
                try {
                    luaFunction.call(Boolean.valueOf(z), luaTable2, str, Integer.valueOf(i));
                } catch (LuaException e) {
                    e.printStackTrace();
                    LuaAccessibilityService.this.a("click", e);
                }
            }
        });
    }

    public boolean click(Point point) {
        return click(point.x, point.y);
    }

    public boolean click(String str, String str2, int[] iArr) {
        AccessibilityNodeInfo rootInActiveWindow;
        if (str == null || str2 == null || !str.equals(getAppName(getFocusView())) || (rootInActiveWindow = getRootInActiveWindow()) == null || rootInActiveWindow.findAccessibilityNodeInfosByText(str2).isEmpty()) {
            return false;
        }
        AccessibilityNodeInfo child = rootInActiveWindow;
        for (int i : iArr) {
            if (child.getChildCount() <= i || (child = child.getChild(i)) == null) {
                return false;
            }
        }
        return toClick(child);
    }

    public boolean copy() {
        return copy(getText(getFocusView()));
    }

    public boolean copy(CharSequence charSequence) {
        if (charSequence == null) {
            return false;
        }
        ((ClipboardManager) getSystemService("clipboard")).setPrimaryClip(ClipData.newPlainText("label", charSequence.toString()));
        return true;
    }

    public boolean deleteApp(String str) {
        this.e.clear();
        b();
        ComponentName componentName = this.e.get(str.toLowerCase());
        if (componentName == null) {
            return false;
        }
        Intent intent = new Intent("android.intent.action.DELETE", Uri.parse("package:" + componentName.getPackageName()));
        intent.setFlags(270532608);
        startActivity(intent);
        return true;
    }

    /* JADX WARN: Can't fix incorrect switch cases order, some code will duplicate */
    /* JADX WARN: Removed duplicated region for block: B:50:0x00ad  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public boolean execute(java.lang.String r4, android.view.accessibility.AccessibilityNodeInfo r5) {
        /*
            Method dump skipped, instruction units count: 374
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaAccessibilityService.execute(java.lang.String, android.view.accessibility.AccessibilityNodeInfo):boolean");
    }

    public AccessibilityNodeInfo findAccessibilityNodeInfo(String str) {
        int iLastIndexOf = str.lastIndexOf("@");
        if (iLastIndexOf > 0) {
            if (!str.substring(iLastIndexOf + 1).equals(getAppName(getFocusView()))) {
                return null;
            }
            str = str.substring(0, iLastIndexOf);
        }
        int iLastIndexOf2 = str.lastIndexOf("#");
        int iIntValue = -1;
        if (iLastIndexOf2 > 0) {
            try {
                iIntValue = Integer.valueOf(str.substring(iLastIndexOf2 + 1)).intValue();
            } catch (Exception unused) {
            }
            str = str.substring(0, iLastIndexOf2);
        }
        char cCharAt = str.charAt(0);
        if (cCharAt == '$') {
            return findAccessibilityNodeInfoByIndex(str.substring(1));
        }
        if (cCharAt == '%') {
            if (execute(str.substring(1), getFocusView())) {
                return AccessibilityNodeInfo.obtain();
            }
            return null;
        }
        if (cCharAt != '>') {
            return cCharAt != '@' ? findAccessibilityNodeInfoByText(str, iIntValue) : findAccessibilityNodeInfoById(str.substring(1), iIntValue);
        }
        if (startApp(str.substring(1))) {
            return AccessibilityNodeInfo.obtain();
        }
        return null;
    }

    public AccessibilityNodeInfo findAccessibilityNodeInfoById(String str, int i) {
        int size;
        List<AccessibilityNodeInfo> listFindAccessibilityNodeInfoById = findAccessibilityNodeInfoById(str);
        if (!listFindAccessibilityNodeInfoById.isEmpty() && i + 1 <= (size = listFindAccessibilityNodeInfoById.size()) && 0 - i <= size) {
            return i < 0 ? listFindAccessibilityNodeInfoById.get(listFindAccessibilityNodeInfoById.size() + i) : listFindAccessibilityNodeInfoById.get(i);
        }
        return null;
    }

    public List<AccessibilityNodeInfo> findAccessibilityNodeInfoById(String str) {
        AccessibilityNodeInfo rootInActiveWindow = getRootInActiveWindow();
        return rootInActiveWindow == null ? new ArrayList() : rootInActiveWindow.findAccessibilityNodeInfosByText(str);
    }

    public AccessibilityNodeInfo findAccessibilityNodeInfoByIndex(String str) {
        AccessibilityNodeInfo rootInActiveWindow = getRootInActiveWindow();
        if (rootInActiveWindow == null) {
            return null;
        }
        for (String str2 : str.split("-")) {
            try {
                int iIntValue = Integer.valueOf(str2).intValue();
                if (rootInActiveWindow.getChildCount() <= iIntValue || (rootInActiveWindow = rootInActiveWindow.getChild(iIntValue)) == null) {
                    return null;
                }
            } catch (Exception e) {
                e.printStackTrace();
                return null;
            }
        }
        return rootInActiveWindow;
    }

    public AccessibilityNodeInfo findAccessibilityNodeInfoByText(String str, int i) {
        int size;
        List<AccessibilityNodeInfo> listFindAccessibilityNodeInfoByText = findAccessibilityNodeInfoByText(str);
        if (!listFindAccessibilityNodeInfoByText.isEmpty() && i + 1 <= (size = listFindAccessibilityNodeInfoByText.size()) && 0 - i <= size) {
            return i < 0 ? listFindAccessibilityNodeInfoByText.get(listFindAccessibilityNodeInfoByText.size() + i) : listFindAccessibilityNodeInfoByText.get(i);
        }
        return null;
    }

    /* JADX WARN: Removed duplicated region for block: B:20:0x0056  */
    /* JADX WARN: Removed duplicated region for block: B:22:0x005c  */
    /* JADX WARN: Removed duplicated region for block: B:26:0x0073  */
    /* JADX WARN: Removed duplicated region for block: B:39:0x00c8  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public java.util.List<android.view.accessibility.AccessibilityNodeInfo> findAccessibilityNodeInfoByText(java.lang.String r17) {
        /*
            Method dump skipped, instruction units count: 261
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaAccessibilityService.findAccessibilityNodeInfoByText(java.lang.String):java.util.List");
    }

    public boolean findClick(String[] strArr) {
        for (String str : strArr) {
            AccessibilityNodeInfo accessibilityNodeInfoFindAccessibilityNodeInfoByText = findAccessibilityNodeInfoByText(str, 0);
            if (accessibilityNodeInfoFindAccessibilityNodeInfoByText != null && a(accessibilityNodeInfoFindAccessibilityNodeInfoByText).performAction(16)) {
                return true;
            }
        }
        return false;
    }

    public ArrayList<AccessibilityNodeInfo> getAllEditTextList() {
        ArrayList<AccessibilityNodeInfo> arrayList = new ArrayList<>();
        getEditText(getRootInActiveWindow(), arrayList);
        return arrayList;
    }

    public String getAllText(int i) {
        ArrayList<String> allTextList = getAllTextList();
        StringBuilder sb = new StringBuilder();
        for (String str : allTextList) {
            if (str.length() > i) {
                sb.append(str);
                sb.append("\n");
            }
        }
        return sb.toString();
    }

    public ArrayList<String> getAllTextList() {
        ArrayList<String> arrayList = new ArrayList<>();
        a(getRootInActiveWindow(), arrayList);
        return arrayList;
    }

    public ArrayList<String> getAllTextList(AccessibilityNodeInfo accessibilityNodeInfo) {
        ArrayList<String> arrayList = new ArrayList<>();
        AccessibilityNodeInfo rootInActiveWindow = getRootInActiveWindow();
        this.f = !accessibilityNodeInfo.isVisibleToUser();
        a(rootInActiveWindow, arrayList, accessibilityNodeInfo);
        return arrayList;
    }

    public String getAppName(AccessibilityNodeInfo accessibilityNodeInfo) {
        CharSequence packageName;
        if (accessibilityNodeInfo == null || (packageName = accessibilityNodeInfo.getPackageName()) == null) {
            return BuildConfig.FLAVOR;
        }
        String string = packageName.toString();
        PackageManager packageManager = getPackageManager();
        try {
            return packageManager.getApplicationLabel(packageManager.getApplicationInfo(string, 0)).toString();
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
            return BuildConfig.FLAVOR;
        }
    }

    public int getDensity() {
        if (this.j == 0) {
            c();
        }
        return this.j;
    }

    public AccessibilityNodeInfo getEditText() {
        ArrayList<AccessibilityNodeInfo> allEditTextList = getAllEditTextList();
        if (allEditTextList.isEmpty()) {
            return null;
        }
        AccessibilityNodeInfo accessibilityNodeInfo = allEditTextList.get(0);
        if (accessibilityNodeInfo != null) {
            accessibilityNodeInfo.performAction(64);
        }
        return accessibilityNodeInfo;
    }

    public void getEditText(AccessibilityNodeInfo accessibilityNodeInfo, ArrayList<AccessibilityNodeInfo> arrayList) {
        if (accessibilityNodeInfo == null) {
            return;
        }
        if (accessibilityNodeInfo.isEditable()) {
            arrayList.add(accessibilityNodeInfo);
        }
        int childCount = accessibilityNodeInfo.getChildCount();
        if (childCount > 0) {
            for (int i = 0; i < childCount; i++) {
                getEditText(accessibilityNodeInfo.getChild(i), arrayList);
            }
        }
    }

    public AccessibilityNodeInfo getFocusView() {
        return getRootInActiveWindow();
    }

    public Handler getHandler() {
        return this.g;
    }

    public int getHeight() {
        if (this.l == 0) {
            c();
        }
        return this.l;
    }

    public String getNodeInfoText(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return null;
        }
        CharSequence contentDescription = accessibilityNodeInfo.getContentDescription();
        CharSequence text = accessibilityNodeInfo.getText();
        String string = contentDescription != null ? contentDescription.toString() : null;
        if (string != null && string.trim().length() > 0 && (!accessibilityNodeInfo.isEditable() || text == null)) {
            return string;
        }
        if (text == null || text.length() <= 0) {
            return null;
        }
        return text.toString();
    }

    public Bitmap getScreenshot() {
        ScreenShot screenShot = this.i;
        if (screenShot != null) {
            return screenShot.getScreenShot();
        }
        return null;
    }

    public void getScreenshot(final LuaFunction luaFunction) throws Throwable {
        ScreenShot.getScreenCaptureBitmap(this, new ScreenCaptureListener() { // from class: com.androlua.LuaAccessibilityService.1
            @Override // com.nirenr.screencapture.ScreenCaptureListener
            public void onScreenCaptureDone(Bitmap bitmap) {
                try {
                    luaFunction.call(bitmap);
                } catch (LuaException e) {
                    e.printStackTrace();
                }
            }

            @Override // com.nirenr.screencapture.ScreenCaptureListener
            public void onScreenCaptureError(String str) {
                try {
                    luaFunction.call(null, str);
                } catch (LuaException e) {
                    e.printStackTrace();
                }
            }
        });
    }

    public String getText(AccessibilityNodeInfo accessibilityNodeInfo) {
        return getNodeInfoText(accessibilityNodeInfo);
    }

    public int getWidth() {
        if (this.k == 0) {
            c();
        }
        return this.k;
    }

    public boolean insert(AccessibilityNodeInfo accessibilityNodeInfo, CharSequence charSequence) {
        if (accessibilityNodeInfo != null && charSequence != null && accessibilityNodeInfo.isEditable()) {
            if (!accessibilityNodeInfo.isFocused()) {
                accessibilityNodeInfo.performAction(1);
            }
            ClipboardManager clipboardManager = (ClipboardManager) getSystemService("clipboard");
            clipboardManager.setPrimaryClip(ClipData.newPlainText("label", charSequence));
            clipboardManager.setText(charSequence);
            if (accessibilityNodeInfo.performAction(32768)) {
                return true;
            }
        }
        return false;
    }

    public boolean installApp(String str) {
        if (str == null) {
            return false;
        }
        Intent intent = new Intent("android.intent.action.VIEW", Uri.parse("market://search?q=" + str));
        intent.setFlags(270532608);
        try {
            startActivity(intent);
            return true;
        } catch (Exception unused) {
            return false;
        }
    }

    public boolean isClickable(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return false;
        }
        if (accessibilityNodeInfo.isClickable() || accessibilityNodeInfo.isCheckable()) {
            return true;
        }
        if (Build.VERSION.SDK_INT >= 21) {
            if (accessibilityNodeInfo.getActionList().contains(AccessibilityNodeInfo.AccessibilityAction.ACTION_CLICK)) {
                return true;
            }
        } else if ((accessibilityNodeInfo.getActions() & 16) != 0) {
            return true;
        }
        return false;
    }

    /* JADX WARN: Failed to restore switch over string. Please report as a decompilation issue */
    public boolean isListView2(AccessibilityNodeInfo accessibilityNodeInfo) {
        CharSequence className;
        if (accessibilityNodeInfo != null && (className = accessibilityNodeInfo.getClassName()) != null) {
            String string = className.toString();
            byte b2 = -1;
            switch (string.hashCode()) {
                case -1433025002:
                    if (string.equals("android.widget.GridView")) {
                        b2 = 2;
                    }
                    break;
                case -1154346071:
                    if (string.equals("android.widget.AdapterView")) {
                        b2 = 0;
                    }
                    break;
                case -1102376577:
                    if (string.equals("com.tencent.widget.GridView")) {
                        b2 = 9;
                    }
                    break;
                case -703660929:
                    if (string.equals("android.support.v7.widget.RecyclerView")) {
                        b2 = 5;
                    }
                    break;
                case -438596061:
                    if (string.equals("flyme.support.v7.widget.RecyclerView")) {
                        b2 = 6;
                    }
                    break;
                case -405438610:
                    if (string.equals("android.widget.ListView")) {
                        b2 = 1;
                    }
                    break;
                case 841510749:
                    if (string.equals("android.widget.ScrollView")) {
                        b2 = 7;
                    }
                    break;
                case 1799238850:
                    if (string.equals("android.widget.ExpandableListView")) {
                        b2 = 4;
                    }
                    break;
                case 1928354017:
                    if (string.equals("android.widget.HorizontalScrollView")) {
                        b2 = 8;
                    }
                    break;
                case 1977625610:
                    if (string.equals("android.widget.AbsListView")) {
                        b2 = 3;
                    }
                    break;
            }
            switch (b2) {
                default:
                    if (string.endsWith("ScrollView") || string.endsWith("GridView") || string.endsWith("RecyclerView") || string.endsWith("ListView")) {
                        return true;
                    }
                case 0:
                case 1:
                case 2:
                case 3:
                case 4:
                case 5:
                case 6:
                case 7:
                case 8:
                case 9:
                    return true;
            }
        }
        return false;
    }

    public boolean longClick(int i, int i2) {
        GlobalActionAutomator globalActionAutomator = this.h;
        if (globalActionAutomator != null) {
            return globalActionAutomator.longClick(i, i2);
        }
        return false;
    }

    public boolean longClick(Point point) {
        return longClick(point.x, point.y);
    }

    public ClickRunnable loopClick(final LuaTable luaTable) {
        ClickRunnable clickRunnable = new ClickRunnable(this, luaTable);
        clickRunnable.canClick(new ClickRunnable.ClickCallback() { // from class: com.androlua.LuaAccessibilityService.7
            @Override // com.androlua.util.ClickRunnable.ClickCallback
            public void onDone(boolean z, LuaTable luaTable2, String str, int i) {
                LuaAccessibilityService.this.loopClick(luaTable);
            }
        });
        return clickRunnable;
    }

    @Override // android.accessibilityservice.AccessibilityService
    public void onAccessibilityEvent(AccessibilityEvent accessibilityEvent) {
        LuaTable luaTable;
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks != null) {
            accessibilityServiceCallbacks.onAccessibilityEvent(this, accessibilityEvent);
        }
        LuaFunction luaFunction = onAccessibilityEvent;
        if (luaFunction != null) {
            try {
                luaFunction.call(accessibilityEvent);
                return;
            } catch (LuaException e) {
                Log.i("lua", "onAccessibilityEvent: " + e.toString());
                return;
            }
        }
        if (this.d.containsKey("LuaAccessibilityService") && (luaTable = (LuaTable) this.d.get("LuaAccessibilityService")) != null) {
            try {
                ((LuaFunction) luaTable.get("onAccessibilityEvent")).call(accessibilityEvent);
            } catch (LuaException e2) {
                LuaFunction luaFunction2 = (LuaFunction) luaTable.get("onError");
                if (luaFunction2 == null) {
                    Log.i("onAccessibilityEvent", e2.getMessage());
                    return;
                }
                try {
                    luaFunction2.call(e2);
                } catch (LuaException unused) {
                    Log.i("onAccessibilityEvent", e2.getMessage());
                }
            }
        }
    }

    @Override // android.app.Service, android.content.ComponentCallbacks
    public void onConfigurationChanged(Configuration configuration) {
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks != null) {
            accessibilityServiceCallbacks.onConfigurationChanged(this, configuration);
        }
    }

    @Override // android.app.Service
    public void onCreate() {
        LuaTable luaTable;
        Log.i("lua", "onCreate");
        super.onCreate();
        this.g = new Handler();
        f700b = this;
        if (Build.VERSION.SDK_INT >= 24) {
            this.h = new GlobalActionAutomator(this, new Handler());
            this.h.setService(this);
        }
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks != null) {
            accessibilityServiceCallbacks.onCreate(this);
        }
        a();
        this.f701c = (LuaApplication) getApplication();
        this.d = this.f701c.getGlobalData();
        if (this.d.containsKey("LuaAccessibilityService") && (luaTable = (LuaTable) this.d.get("LuaAccessibilityService")) != null) {
            try {
                ((LuaFunction) luaTable.get("onCreate")).call(this);
            } catch (LuaException e) {
                LuaFunction luaFunction = (LuaFunction) luaTable.get("onError");
                if (luaFunction == null) {
                    Log.i("onCreate", e.getMessage());
                    return;
                }
                try {
                    luaFunction.call(e);
                } catch (LuaException unused) {
                    Log.i("onCreate", e.getMessage());
                }
            }
        }
    }

    @Override // android.app.Service
    public void onDestroy() {
        f700b = null;
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks != null) {
            accessibilityServiceCallbacks.onDestroy(this);
        }
        stopScreenshot();
        super.onDestroy();
    }

    @Override // android.accessibilityservice.AccessibilityService
    public void onInterrupt() {
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks != null) {
            accessibilityServiceCallbacks.onInterrupt(this);
        }
    }

    @Override // android.accessibilityservice.AccessibilityService
    protected boolean onKeyEvent(KeyEvent keyEvent) {
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks == null || !accessibilityServiceCallbacks.onKeyEvent(this, keyEvent)) {
            return super.onKeyEvent(keyEvent);
        }
        return true;
    }

    @Override // android.accessibilityservice.AccessibilityService
    protected void onServiceConnected() {
        LuaTable luaTable;
        Log.i("lua", "onServiceConnected");
        super.onServiceConnected();
        AccessibilityServiceCallbacks accessibilityServiceCallbacks = f699a;
        if (accessibilityServiceCallbacks != null) {
            accessibilityServiceCallbacks.onServiceConnected(this);
        }
        if (this.d.containsKey("LuaAccessibilityService") && (luaTable = (LuaTable) this.d.get("LuaAccessibilityService")) != null) {
            try {
                ((LuaFunction) luaTable.get("onServiceConnected")).call(this);
            } catch (LuaException e) {
                LuaFunction luaFunction = (LuaFunction) luaTable.get("onError");
                if (luaFunction == null) {
                    Log.i("onServiceConnected", e.getMessage());
                    return;
                }
                try {
                    luaFunction.call(e);
                } catch (LuaException unused) {
                    Log.i("onServiceConnected", e.getMessage());
                }
            }
        }
    }

    public boolean paste() {
        return paste(getFocusView(), ((ClipboardManager) getSystemService("clipboard")).getText());
    }

    public boolean paste(AccessibilityNodeInfo accessibilityNodeInfo) {
        return paste(accessibilityNodeInfo, ((ClipboardManager) getSystemService("clipboard")).getText());
    }

    public boolean paste(AccessibilityNodeInfo accessibilityNodeInfo, CharSequence charSequence) {
        if (accessibilityNodeInfo == null || charSequence == null) {
            return false;
        }
        if (accessibilityNodeInfo.isEditable()) {
            if (!accessibilityNodeInfo.isFocused()) {
                accessibilityNodeInfo.performAction(1);
            }
            ClipboardManager clipboardManager = (ClipboardManager) getSystemService("clipboard");
            clipboardManager.setPrimaryClip(ClipData.newPlainText("label", charSequence));
            clipboardManager.setText(charSequence);
            if (accessibilityNodeInfo.performAction(32768)) {
                return true;
            }
        }
        return paste(charSequence);
    }

    public boolean paste(CharSequence charSequence) {
        AccessibilityNodeInfo editText;
        if (charSequence == null || (editText = getEditText()) == null) {
            return false;
        }
        if (getFocusView().isEditable() && getFocusView().getText() != null) {
            charSequence = getFocusView().getText().toString() + ((Object) charSequence);
        }
        if (Build.VERSION.SDK_INT < 21) {
            return false;
        }
        Bundle bundle = new Bundle();
        bundle.putCharSequence("ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE", charSequence);
        return editText.performAction(2097152, bundle);
    }

    public void postClick(long j, final LuaTable luaTable) {
        this.g.postDelayed(new Runnable() { // from class: com.androlua.LuaAccessibilityService.4
            @Override // java.lang.Runnable
            public void run() {
                LuaAccessibilityService.this.click(luaTable);
            }
        }, j);
    }

    public void postClick(long j, final LuaTable luaTable, final LuaFunction luaFunction) {
        this.g.postDelayed(new Runnable() { // from class: com.androlua.LuaAccessibilityService.5
            @Override // java.lang.Runnable
            public void run() {
                LuaAccessibilityService.this.click(luaTable, luaFunction);
            }
        }, j);
    }

    public void postExecute(long j, final String str, final AccessibilityNodeInfo accessibilityNodeInfo) {
        this.g.postDelayed(new Runnable() { // from class: com.androlua.LuaAccessibilityService.3
            @Override // java.lang.Runnable
            public void run() {
                LuaAccessibilityService.this.execute(str, accessibilityNodeInfo);
            }
        }, j);
    }

    public void postExecute(long j, final String str, final AccessibilityNodeInfo accessibilityNodeInfo, final LuaFunction luaFunction) {
        this.g.postDelayed(new Runnable() { // from class: com.androlua.LuaAccessibilityService.2
            @Override // java.lang.Runnable
            public void run() {
                try {
                    luaFunction.call(Boolean.valueOf(LuaAccessibilityService.this.execute(str, accessibilityNodeInfo)), str, accessibilityNodeInfo);
                } catch (LuaException e) {
                    e.printStackTrace();
                    LuaAccessibilityService.this.a("postExecute", e);
                }
            }
        }, j);
    }

    public boolean press(int i, int i2, int i3) {
        GlobalActionAutomator globalActionAutomator = this.h;
        if (globalActionAutomator != null) {
            return globalActionAutomator.press(i, i2, i3);
        }
        return false;
    }

    public boolean press(Point point, int i) {
        return press(point.x, point.y, i);
    }

    public boolean scrollBackward(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return false;
        }
        if (Build.VERSION.SDK_INT < 21) {
            if ((accessibilityNodeInfo.getActions() & 8192) == 0) {
                return false;
            }
        } else if (!accessibilityNodeInfo.getActionList().contains(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD)) {
            return false;
        }
        return accessibilityNodeInfo.performAction(8192);
    }

    public boolean scrollForward(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return false;
        }
        if (Build.VERSION.SDK_INT < 21) {
            if ((accessibilityNodeInfo.getActions() & 4096) == 0) {
                return false;
            }
        } else if (!accessibilityNodeInfo.getActionList().contains(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD)) {
            return false;
        }
        return accessibilityNodeInfo.performAction(4096);
    }

    public boolean setText(AccessibilityNodeInfo accessibilityNodeInfo, String str) {
        if (accessibilityNodeInfo == null || !accessibilityNodeInfo.isEditable()) {
            return false;
        }
        if (Build.VERSION.SDK_INT < 21) {
            return paste(accessibilityNodeInfo, str);
        }
        Bundle bundle = new Bundle();
        bundle.putCharSequence("ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE", str);
        return accessibilityNodeInfo.performAction(2097152, bundle);
    }

    public boolean setText(String str) {
        return setText(getEditText(), str);
    }

    public boolean startApp(String str) {
        a();
        ComponentName componentName = this.e.get(str.toLowerCase());
        if (componentName == null) {
            return false;
        }
        Intent intent = new Intent("android.intent.action.MAIN");
        intent.addCategory("android.intent.category.DEFAULT");
        intent.setComponent(componentName);
        intent.setFlags(270532608);
        try {
            startActivity(intent);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public void startScreenshot() {
        this.i = new ScreenShot(this, null);
    }

    public void startScreenshot(VirtualDisplay.Callback callback) {
        this.i = new ScreenShot(this, callback);
    }

    public void stopScreenshot() {
        ScreenShot screenShot = this.i;
        if (screenShot != null) {
            screenShot.release();
        }
        this.i = null;
    }

    public boolean swipe(int i, int i2, int i3, int i4, int i5) {
        GlobalActionAutomator globalActionAutomator = this.h;
        if (globalActionAutomator != null) {
            return globalActionAutomator.swipe(i, i2, i3, i4, i5);
        }
        return false;
    }

    public boolean swipe(Path path, int i) {
        GlobalActionAutomator globalActionAutomator = this.h;
        if (globalActionAutomator != null) {
            return globalActionAutomator.gesture(0L, i, path);
        }
        return false;
    }

    public boolean swipe(Point point, Point point2, int i) {
        return swipe(point.x, point.y, point2.x, point2.y, i);
    }

    public void toBack() {
        performGlobalAction(1);
    }

    public boolean toClick(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return false;
        }
        try {
            return accessibilityNodeInfo.performAction(16);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public void toClick2(AccessibilityNodeInfo accessibilityNodeInfo) {
        toClick(a(accessibilityNodeInfo));
    }

    public void toHome() {
        performGlobalAction(2);
    }

    public boolean toLongClick(AccessibilityNodeInfo accessibilityNodeInfo) {
        if (accessibilityNodeInfo == null) {
            return false;
        }
        try {
            return accessibilityNodeInfo.performAction(32);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public void toNotifications() {
        performGlobalAction(4);
    }

    public void toRecents() {
        performGlobalAction(3);
    }
}