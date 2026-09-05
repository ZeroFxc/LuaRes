package com.androlua;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Typeface;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.ActionMode;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.EditText;
import android.widget.RadioGroup;
import android.widget.TextView;
import android.widget.Toast;
import b.b.a.a.r;
import b.b.a.a.x;
import b.b.a.a.y;
import b.b.a.b.c;
import b.b.a.b.d;
import b.b.a.b.e;
import b.b.a.b.f;
import b.b.a.b.g;
import b.b.a.b.j;
import b.b.a.b.m;
import b.b.a.b.n;
import b.b.a.b.p;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaEditor extends r {
    private boolean ka;
    private Context la;
    private String ma;
    private String na;
    private String oa;
    private int pa;
    private n qa;
    private int ra;
    private String sa;

    @SuppressLint({"StaticFieldLeak"})
    public LuaEditor(Context context) {
        super(context);
        this.na = LuaApplication.getInstance().getLuaExtDir("fonts");
        this.oa = LuaApplication.getInstance().getLuaExtPath("android.jar");
        this.la = context;
        setTypeface(Typeface.MONOSPACE);
        File file = new File(this.na, "default.ttf");
        if (file.exists()) {
            setTypeface(Typeface.createFromFile(file));
        }
        File file2 = new File(this.na, "bold.ttf");
        if (file2.exists()) {
            setBoldTypeface(Typeface.createFromFile(file2));
        }
        File file3 = new File(this.na, "italic.ttf");
        if (file3.exists()) {
            setItalicTypeface(Typeface.createFromFile(file3));
        }
        setTextSize((int) TypedValue.applyDimension(2, r.f175c, context.getResources().getDisplayMetrics()));
        setShowLineNumbers(true);
        setHighlightCurrentRow(true);
        setWordWrap(false);
        setAutoIndentWidth(2);
        m.a(j.f());
        setNavigationMethod(isAccessibilityEnabled() ? new x(this) : new y(this));
        TypedArray typedArrayObtainStyledAttributes = this.la.getTheme().obtainStyledAttributes(new int[]{android.R.attr.colorBackground, android.R.attr.textColorPrimary, android.R.attr.textColorHighlight});
        typedArrayObtainStyledAttributes.getColor(0, 16711935);
        int color = typedArrayObtainStyledAttributes.getColor(1, 16711935);
        int color2 = typedArrayObtainStyledAttributes.getColor(2, 16711935);
        typedArrayObtainStyledAttributes.recycle();
        setTextColor(color);
        setTextHighlightColor(color2);
        p.a(context);
    }

    public void addNames(String[] strArr) {
        j jVar = (j) m.c();
        String[] strArrC = jVar.c();
        String[] strArr2 = new String[strArrC.length + strArr.length];
        System.arraycopy(strArrC, 0, strArr2, 0, strArrC.length);
        System.arraycopy(strArr, 0, strArr2, strArrC.length, strArr.length);
        jVar.b(strArr2);
        m.a(jVar);
        respan();
        invalidate();
    }

    public void addPackage(String str, String[] strArr) {
        j jVar = (j) m.c();
        jVar.a(str, strArr);
        m.a(jVar);
        respan();
        invalidate();
    }

    public boolean findNext(String str) {
        if (!str.equals(this.sa)) {
            this.sa = str;
            this.ra = 0;
        }
        this.qa = new n();
        String str2 = this.sa;
        if (str2.isEmpty()) {
            selectText(false);
            return false;
        }
        this.ra = this.qa.a(getText(), str2, this.ra, getText().length(), false, false);
        int i = this.ra;
        if (i == -1) {
            selectText(false);
            Toast.makeText(this.la, "\u672a\u627e\u5230", 0).show();
            this.ra = 0;
            return false;
        }
        setSelection(i, this.sa.length());
        this.ra += this.sa.length();
        moveCaret(this.ra);
        return true;
    }

    public String getFilePath() {
        return this.ma;
    }

    public String getSelectedText() {
        return this.i.subSequence(getSelectionStart(), getSelectionEnd() - getSelectionStart()).toString();
    }

    public g getText() {
        return createDocumentProvider();
    }

    public void gotoLine() {
        startGotoMode();
    }

    public void gotoLine(int i) {
        if (i > this.i.f()) {
            i = this.i.f();
        }
        setSelection(getText().c(i - 1));
    }

    public void insert(int i, String str) {
        selectText(false);
        moveCaret(i);
        paste(str);
    }

    @Override // android.view.View
    public boolean onKeyShortcut(int i, KeyEvent keyEvent) {
        if (KeyEvent.metaStateHasNoModifiers(keyEvent.getMetaState() & (-28673))) {
            if (i == 29) {
                selectAll();
                return true;
            }
            if (i == 31) {
                copy();
                return true;
            }
            if (i == 35) {
                gotoLine();
                return true;
            }
            if (i == 40) {
                format();
                return true;
            }
            if (i == 47) {
                search();
                return true;
            }
            if (i == 50) {
                paste();
                return true;
            }
            if (i == 52) {
                cut();
                return true;
            }
        }
        return super.onKeyShortcut(i, keyEvent);
    }

    @Override // b.b.a.a.r, android.view.View
    protected void onLayout(boolean z, int i, int i2, int i3, int i4) {
        super.onLayout(z, i, i2, i3, i4);
        int i5 = this.pa;
        if (i5 == 0 || i3 <= 0) {
            return;
        }
        moveCaret(i5);
        this.pa = 0;
    }

    public void open(String str) throws IOException {
        this.ma = str;
        BufferedReader bufferedReader = new BufferedReader(new FileReader(str));
        StringBuilder sb = new StringBuilder();
        while (true) {
            String line = bufferedReader.readLine();
            if (line == null) {
                break;
            }
            sb.append(line);
            sb.append("\n");
        }
        if (sb.length() > 1) {
            sb.setLength(sb.length() - 1);
        }
        setText(sb);
    }

    @Override // b.b.a.a.r, android.view.View
    @TargetApi(21)
    public boolean performAccessibilityAction(int i, Bundle bundle) {
        if (i == 256) {
            int i2 = bundle.getInt("ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT");
            if (i2 != 1) {
                if (i2 == 4) {
                    moveCaretDown();
                } else if (i2 == 16) {
                    return false;
                }
            } else {
                if (getCaretPosition() >= getLength() - 1) {
                    return false;
                }
                moveCaretRight();
            }
            return true;
        }
        if (i == 512) {
            int i3 = bundle.getInt("ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT");
            if (i3 == 1) {
                if (getCaretPosition() <= 0) {
                    return false;
                }
                moveCaretLeft();
                return true;
            }
            if (i3 == 4) {
                moveCaretUp();
            } else if (i3 == 16) {
                return false;
            }
            return true;
        }
        if (i == 16384) {
            copy();
            return true;
        }
        if (i == 32768) {
            paste();
            return true;
        }
        if (i == 65536) {
            cut();
            return true;
        }
        if (i != 131072) {
            if (i != 2097152) {
                return super.performAccessibilityAction(i, bundle);
            }
            selectText(false);
            setText(bundle == null ? BuildConfig.FLAVOR : bundle.getCharSequence("ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE"), true);
            return true;
        }
        if (bundle == null) {
            return true;
        }
        int i4 = bundle.getInt("ACTION_ARGUMENT_SELECTION_START_INT", 0);
        int i5 = bundle.getInt("ACTION_ARGUMENT_SELECTION_END_INT", 0);
        if (bundle.getBoolean("ACTION_ARGUMENT_EXTEND_SELECTION_BOOLEAN", false)) {
            setSelectionRange(i4, i5);
        } else {
            setSelection(i4);
        }
        return true;
    }

    public void redo() {
        int iL = createDocumentProvider().l();
        if (iL >= 0) {
            setEdited(true);
            respan();
            selectText(false);
            moveCaret(iL);
            invalidate();
        }
    }

    public void removePackage(String str) {
        j jVar = (j) m.c();
        jVar.g(str);
        m.a(jVar);
        respan();
        invalidate();
    }

    public boolean save() {
        return save(this.ma);
    }

    public boolean save(String str) throws IOException {
        if (str == null) {
            return true;
        }
        File file = new File(str);
        if (file.exists() && !file.canWrite()) {
            return false;
        }
        BufferedWriter bufferedWriter = new BufferedWriter(new FileWriter(str));
        bufferedWriter.write(getText().toString());
        bufferedWriter.close();
        return true;
    }

    public void search() {
        startFindMode();
    }

    @Override // android.view.View
    public void setBackgroundColor(int i) {
        getColorScheme().a(c.a.BACKGROUND, i);
    }

    public void setBasewordColor(int i) {
        getColorScheme().a(c.a.NAME, i);
    }

    public void setCommentColor(int i) {
        getColorScheme().a(c.a.COMMENT, i);
    }

    public void setDark(boolean z) {
        setColorScheme(z ? new d() : new e());
    }

    public void setKeywordColor(int i) {
        getColorScheme().a(c.a.KEYWORD, i);
    }

    public void setPanelBackgroundColor(int i) {
        this.t.a(i);
    }

    public void setPanelTextColor(int i) {
        this.t.b(i);
    }

    public void setSelection(int i) {
        selectText(false);
        if (hasLayout()) {
            this.pa = i;
        } else {
            moveCaret(i);
        }
    }

    public void setStringColor(int i) {
        getColorScheme().a(c.a.STRING, i);
    }

    public void setText(CharSequence charSequence) {
        f fVar = new f(this);
        fVar.a(this.ka);
        fVar.a(charSequence);
        setDocumentProvider(new g(fVar));
    }

    public void setText(CharSequence charSequence, boolean z) {
        replaceText(0, getLength() - 1, charSequence.toString());
    }

    public void setTextColor(int i) {
        getColorScheme().a(c.a.FOREGROUND, i);
    }

    public void setTextHighlightColor(int i) {
        getColorScheme().a(c.a.SELECTION_BACKGROUND, i);
    }

    public void setUserwordColor(int i) {
        getColorScheme().a(c.a.LITERAL, i);
    }

    @Override // b.b.a.a.r
    public void setWordWrap(boolean z) {
        this.ka = z;
        super.setWordWrap(z);
    }

    public void startFindMode() {
        startActionMode(new ActionMode.Callback() { // from class: com.androlua.LuaEditor.2

            /* JADX INFO: renamed from: a, reason: collision with root package name */
            private n f788a;

            /* JADX INFO: renamed from: b, reason: collision with root package name */
            private int f789b;

            /* JADX INFO: renamed from: c, reason: collision with root package name */
            private EditText f790c;

            private void a() {
                this.f788a = new n();
                String string = this.f790c.getText().toString();
                if (string.isEmpty()) {
                    LuaEditor.this.selectText(false);
                    return;
                }
                this.f789b = this.f788a.a(LuaEditor.this.getText(), string, this.f789b, LuaEditor.this.getText().length(), false, false);
                int i = this.f789b;
                if (i == -1) {
                    LuaEditor.this.selectText(false);
                    Toast.makeText(LuaEditor.this.la, "\u672a\u627e\u5230", 0).show();
                    this.f789b = 0;
                } else {
                    LuaEditor.this.setSelection(i, this.f790c.getText().length());
                    this.f789b += this.f790c.getText().length();
                    LuaEditor.this.moveCaret(this.f789b);
                }
            }

            @Override // android.view.ActionMode.Callback
            public boolean onActionItemClicked(ActionMode actionMode, MenuItem menuItem) {
                int itemId = menuItem.getItemId();
                if (itemId == 1 || itemId != 2) {
                    return false;
                }
                a();
                return false;
            }

            @Override // android.view.ActionMode.Callback
            public boolean onCreateActionMode(ActionMode actionMode, Menu menu) {
                actionMode.setTitle("\u641c\u7d22");
                actionMode.setSubtitle((CharSequence) null);
                this.f790c = new EditText(LuaEditor.this.la) { // from class: com.androlua.LuaEditor.2.1
                    @Override // android.widget.TextView
                    public void onTextChanged(CharSequence charSequence, int i, int i2, int i3) {
                        if (charSequence.length() > 0) {
                            AnonymousClass2.this.f789b = 0;
                            a();
                        }
                    }
                };
                this.f790c.setSingleLine(true);
                this.f790c.setImeOptions(3);
                this.f790c.setOnEditorActionListener(new TextView.OnEditorActionListener() { // from class: com.androlua.LuaEditor.2.2
                    @Override // android.widget.TextView.OnEditorActionListener
                    public boolean onEditorAction(TextView textView, int i, KeyEvent keyEvent) {
                        a();
                        return true;
                    }
                });
                this.f790c.setLayoutParams(new RadioGroup.LayoutParams(LuaEditor.this.getWidth() / 3, -1));
                menu.add(0, 1, 0, BuildConfig.FLAVOR).setActionView(this.f790c);
                menu.add(0, 2, 0, LuaEditor.this.la.getString(android.R.string.search_go));
                this.f790c.requestFocus();
                return true;
            }

            @Override // android.view.ActionMode.Callback
            public void onDestroyActionMode(ActionMode actionMode) {
            }

            @Override // android.view.ActionMode.Callback
            public boolean onPrepareActionMode(ActionMode actionMode, Menu menu) {
                return false;
            }
        });
    }

    public void startGotoMode() {
        startActionMode(new ActionMode.Callback() { // from class: com.androlua.LuaEditor.1

            /* JADX INFO: renamed from: a, reason: collision with root package name */
            private int f783a;

            /* JADX INFO: renamed from: b, reason: collision with root package name */
            private EditText f784b;

            private void a() {
                String string = this.f784b.getText().toString();
                if (string.isEmpty()) {
                    return;
                }
                int iIntValue = Integer.valueOf(string).intValue();
                if (iIntValue > ((r) LuaEditor.this).i.f()) {
                    iIntValue = ((r) LuaEditor.this).i.f();
                }
                LuaEditor.this.gotoLine(iIntValue);
            }

            @Override // android.view.ActionMode.Callback
            public boolean onActionItemClicked(ActionMode actionMode, MenuItem menuItem) {
                int itemId = menuItem.getItemId();
                if (itemId == 1 || itemId != 2) {
                    return false;
                }
                a();
                return false;
            }

            @Override // android.view.ActionMode.Callback
            public boolean onCreateActionMode(ActionMode actionMode, Menu menu) {
                actionMode.setTitle("\u8f6c\u5230");
                actionMode.setSubtitle((CharSequence) null);
                this.f784b = new EditText(LuaEditor.this.la) { // from class: com.androlua.LuaEditor.1.1
                    @Override // android.widget.TextView
                    public void onTextChanged(CharSequence charSequence, int i, int i2, int i3) {
                        if (charSequence.length() > 0) {
                            AnonymousClass1.this.f783a = 0;
                            a();
                        }
                    }
                };
                this.f784b.setSingleLine(true);
                this.f784b.setInputType(2);
                this.f784b.setImeOptions(2);
                this.f784b.setOnEditorActionListener(new TextView.OnEditorActionListener() { // from class: com.androlua.LuaEditor.1.2
                    @Override // android.widget.TextView.OnEditorActionListener
                    public boolean onEditorAction(TextView textView, int i, KeyEvent keyEvent) {
                        a();
                        return true;
                    }
                });
                this.f784b.setLayoutParams(new RadioGroup.LayoutParams(LuaEditor.this.getWidth() / 3, -1));
                menu.add(0, 1, 0, BuildConfig.FLAVOR).setActionView(this.f784b);
                menu.add(0, 2, 0, LuaEditor.this.la.getString(android.R.string.ok));
                this.f784b.requestFocus();
                return true;
            }

            @Override // android.view.ActionMode.Callback
            public void onDestroyActionMode(ActionMode actionMode) {
            }

            @Override // android.view.ActionMode.Callback
            public boolean onPrepareActionMode(ActionMode actionMode, Menu menu) {
                return false;
            }
        });
    }

    public void undo() {
        int iM = createDocumentProvider().m();
        if (iM >= 0) {
            setEdited(true);
            respan();
            selectText(false);
            moveCaret(iM);
            invalidate();
        }
    }
}