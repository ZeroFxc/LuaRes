package com.androlua;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.content.res.TypedArray;
import android.content.res.XmlResourceParser;
import android.graphics.Movie;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.util.AttributeSet;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import com.luajava.LuaMetaTable;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import org.xmlpull.v1.XmlPullParserException;

@SuppressLint({"UseSparseArrays"})
/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaResources extends Resources implements LuaMetaTable {
    private static int a = 2131034112;
    private final HashMap<Integer, String> b;
    private final HashMap<Integer, Drawable> c;
    private final HashMap<Integer, Integer> d;
    private final HashMap<Integer, String[]> e;
    private final HashMap<Integer, int[]> f;
    private final HashMap<Integer, Typeface> g;
    private final HashMap<Integer, Integer> h;
    private final HashMap<Integer, Float> i;
    private final HashMap<Integer, Boolean> j;
    private final HashMap<String, Integer> k;
    private Resources l;

    public LuaResources(AssetManager assetManager, DisplayMetrics displayMetrics, Configuration configuration) {
        super(assetManager, displayMetrics, configuration);
        this.b = new HashMap<>();
        this.c = new HashMap<>();
        this.d = new HashMap<>();
        this.e = new HashMap<>();
        this.f = new HashMap<>();
        this.g = new HashMap<>();
        this.h = new HashMap<>();
        this.i = new HashMap<>();
        this.j = new HashMap<>();
        this.k = new HashMap<>();
    }

    @Override // com.luajava.LuaMetaTable
    public Object __call(Object... objArr) {
        return null;
    }

    @Override // com.luajava.LuaMetaTable
    public Object __index(String str) {
        return get(str);
    }

    @Override // com.luajava.LuaMetaTable
    public void __newIndex(String str, Object obj) {
        put(str, obj);
    }

    public Object get(String str) {
        return this.k.get(str);
    }

    @Override // android.content.res.Resources
    public XmlResourceParser getAnimation(int i) {
        return this.l.getAnimation(i);
    }

    @Override // android.content.res.Resources
    public boolean getBoolean(int i) {
        Boolean bool = this.j.get(Integer.valueOf(i));
        return bool != null ? bool.booleanValue() : this.l.getBoolean(i);
    }

    @Override // android.content.res.Resources
    public int getColor(int i) {
        Integer num = this.d.get(Integer.valueOf(i));
        return num != null ? num.intValue() : this.l.getColor(i);
    }

    @Override // android.content.res.Resources
    @TargetApi(23)
    public int getColor(int i, Resources.Theme theme) {
        Integer num = this.d.get(Integer.valueOf(i));
        return num != null ? num.intValue() : this.l.getColor(i, theme);
    }

    @Override // android.content.res.Resources
    public ColorStateList getColorStateList(int i) {
        return this.l.getColorStateList(i);
    }

    @Override // android.content.res.Resources
    @TargetApi(23)
    public ColorStateList getColorStateList(int i, Resources.Theme theme) {
        return this.l.getColorStateList(i, theme);
    }

    @Override // android.content.res.Resources
    public Configuration getConfiguration() {
        return this.l.getConfiguration();
    }

    @Override // android.content.res.Resources
    public float getDimension(int i) {
        return this.l.getDimension(i);
    }

    @Override // android.content.res.Resources
    public int getDimensionPixelOffset(int i) {
        return this.l.getDimensionPixelOffset(i);
    }

    @Override // android.content.res.Resources
    public int getDimensionPixelSize(int i) {
        return this.l.getDimensionPixelSize(i);
    }

    @Override // android.content.res.Resources
    public DisplayMetrics getDisplayMetrics() {
        return this.l.getDisplayMetrics();
    }

    @Override // android.content.res.Resources
    public Drawable getDrawable(int i) {
        Drawable drawable = this.c.get(Integer.valueOf(i));
        return drawable != null ? drawable : this.l.getDrawable(i);
    }

    @Override // android.content.res.Resources
    @TargetApi(21)
    public Drawable getDrawable(int i, Resources.Theme theme) {
        Drawable drawable = this.c.get(Integer.valueOf(i));
        return drawable != null ? drawable : this.l.getDrawable(i, theme);
    }

    @Override // android.content.res.Resources
    public Drawable getDrawableForDensity(int i, int i2) {
        return this.l.getDrawableForDensity(i, i2);
    }

    @Override // android.content.res.Resources
    public Drawable getDrawableForDensity(int i, int i2, Resources.Theme theme) {
        return this.l.getDrawableForDensity(i, i2, theme);
    }

    @Override // android.content.res.Resources
    @TargetApi(26)
    public Typeface getFont(int i) {
        Typeface typeface = this.g.get(Integer.valueOf(i));
        return typeface != null ? typeface : this.l.getFont(i);
    }

    @Override // android.content.res.Resources
    public float getFraction(int i, int i2, int i3) {
        return this.l.getFraction(i, i2, i3);
    }

    @Override // android.content.res.Resources
    public int getIdentifier(String str, String str2, String str3) {
        return this.l.getIdentifier(str, str2, str3);
    }

    @Override // android.content.res.Resources
    public int[] getIntArray(int i) {
        int[] iArr = this.f.get(Integer.valueOf(i));
        return iArr != null ? iArr : this.l.getIntArray(i);
    }

    @Override // android.content.res.Resources
    public int getInteger(int i) {
        Integer num = this.h.get(Integer.valueOf(i));
        return num != null ? num.intValue() : this.l.getInteger(i);
    }

    @Override // android.content.res.Resources
    public XmlResourceParser getLayout(int i) {
        return this.l.getLayout(i);
    }

    @Override // android.content.res.Resources
    public Movie getMovie(int i) {
        return this.l.getMovie(i);
    }

    @Override // android.content.res.Resources
    public String getQuantityString(int i, int i2) {
        return this.l.getQuantityString(i, i2);
    }

    @Override // android.content.res.Resources
    public String getQuantityString(int i, int i2, Object... objArr) {
        return this.l.getQuantityString(i, i2, objArr);
    }

    @Override // android.content.res.Resources
    public CharSequence getQuantityText(int i, int i2) {
        return this.l.getQuantityText(i, i2);
    }

    @Override // android.content.res.Resources
    public String getResourceEntryName(int i) {
        return this.l.getResourceEntryName(i);
    }

    @Override // android.content.res.Resources
    public String getResourceName(int i) {
        return this.l.getResourceName(i);
    }

    @Override // android.content.res.Resources
    public String getResourcePackageName(int i) {
        return this.l.getResourcePackageName(i);
    }

    @Override // android.content.res.Resources
    public String getResourceTypeName(int i) {
        return this.l.getResourceTypeName(i);
    }

    @Override // android.content.res.Resources
    public String getString(int i) {
        return getText(i).toString();
    }

    @Override // android.content.res.Resources
    public String getString(int i, Object... objArr) {
        return String.format(getString(i), objArr);
    }

    @Override // android.content.res.Resources
    public String[] getStringArray(int i) {
        String[] strArr = this.e.get(Integer.valueOf(i));
        return strArr != null ? strArr : this.l.getStringArray(i);
    }

    @Override // android.content.res.Resources
    public CharSequence getText(int i) {
        String str = this.b.get(Integer.valueOf(i));
        return str != null ? str : this.l.getText(i);
    }

    @Override // android.content.res.Resources
    public CharSequence getText(int i, CharSequence charSequence) {
        String str = this.b.get(Integer.valueOf(i));
        return str != null ? str : this.l.getText(i, charSequence);
    }

    @Override // android.content.res.Resources
    public CharSequence[] getTextArray(int i) {
        String[] strArr = this.e.get(Integer.valueOf(i));
        return strArr != null ? strArr : this.l.getTextArray(i);
    }

    @Override // android.content.res.Resources
    public void getValue(int i, TypedValue typedValue, boolean z) throws Resources.NotFoundException {
        this.l.getValue(i, typedValue, z);
    }

    @Override // android.content.res.Resources
    public void getValue(String str, TypedValue typedValue, boolean z) throws Resources.NotFoundException {
        this.l.getValue(str, typedValue, z);
    }

    @Override // android.content.res.Resources
    public void getValueForDensity(int i, int i2, TypedValue typedValue, boolean z) throws Resources.NotFoundException {
        this.l.getValueForDensity(i, i2, typedValue, z);
    }

    @Override // android.content.res.Resources
    public XmlResourceParser getXml(int i) {
        return this.l.getXml(i);
    }

    @Override // android.content.res.Resources
    public TypedArray obtainAttributes(AttributeSet attributeSet, int[] iArr) {
        return this.l.obtainAttributes(attributeSet, iArr);
    }

    @Override // android.content.res.Resources
    public TypedArray obtainTypedArray(int i) {
        return this.l.obtainTypedArray(i);
    }

    @Override // android.content.res.Resources
    public InputStream openRawResource(int i) {
        return this.l.openRawResource(i);
    }

    @Override // android.content.res.Resources
    public InputStream openRawResource(int i, TypedValue typedValue) {
        return this.l.openRawResource(i, typedValue);
    }

    @Override // android.content.res.Resources
    public AssetFileDescriptor openRawResourceFd(int i) {
        return this.l.openRawResourceFd(i);
    }

    @Override // android.content.res.Resources
    public void parseBundleExtra(String str, AttributeSet attributeSet, Bundle bundle) throws XmlPullParserException {
        this.l.parseBundleExtra(str, attributeSet, bundle);
    }

    @Override // android.content.res.Resources
    public void parseBundleExtras(XmlResourceParser xmlResourceParser, Bundle bundle) throws XmlPullParserException, IOException {
        this.l.parseBundleExtras(xmlResourceParser, bundle);
    }

    public int put(String str, Object obj) {
        if (obj == null) {
            throw new NullPointerException();
        }
        int i = a;
        a = i + 1;
        if (obj instanceof Drawable) {
            setDrawable(i, (Drawable) obj);
        } else if (obj instanceof String) {
            setText(i, (String) obj);
        } else if (obj instanceof String[]) {
            setTextArray(i, (String[]) obj);
        } else if (obj instanceof Number) {
            setColor(i, ((Number) obj).intValue());
        } else {
            if (!(obj instanceof int[])) {
                throw new IllegalArgumentException();
            }
            setIntArray(i, (int[]) obj);
        }
        this.k.put(str, Integer.valueOf(i));
        return i;
    }

    public void setBoolean(int i, Boolean bool) {
        this.j.put(Integer.valueOf(i), bool);
    }

    public void setColor(int i, int i2) {
        this.d.put(Integer.valueOf(i), Integer.valueOf(i2));
    }

    public void setDrawable(int i, Drawable drawable) {
        this.c.put(Integer.valueOf(i), drawable);
    }

    public void setFont(int i, Typeface typeface) {
        this.g.put(Integer.valueOf(i), typeface);
    }

    public void setIntArray(int i, int[] iArr) {
        this.f.put(Integer.valueOf(i), iArr);
    }

    public void setString(int i, String str) {
        this.b.put(Integer.valueOf(i), str);
    }

    public void setStringArray(int i, String[] strArr) {
        this.e.put(Integer.valueOf(i), strArr);
    }

    public void setSuperResources(Resources resources) {
        this.l = resources;
    }

    public void setText(int i, String str) {
        this.b.put(Integer.valueOf(i), str);
    }

    public void setTextArray(int i, String[] strArr) {
        this.e.put(Integer.valueOf(i), strArr);
    }
}