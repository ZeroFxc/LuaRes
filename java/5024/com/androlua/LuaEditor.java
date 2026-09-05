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

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
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
        setTextSize((int) TypedValue.applyDimension(2, r.c, context.getResources().getDisplayMetrics()));
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

    /* JADX WARN: Multi-variable type inference failed */
    public void addNames(String[] strArr) {
        j jVarC = m.c();
        String[] strArrC = jVarC.c();
        String[] strArr2 = new String[strArrC.length + strArr.length];
        System.arraycopy(strArrC, 0, strArr2, 0, strArrC.length);
        System.arraycopy(strArr, 0, strArr2, strArrC.length, strArr.length);
        jVarC.b(strArr2);
        m.a(jVarC);
        respan();
        invalidate();
    }

    /* JADX WARN: Multi-variable type inference failed */
    public void addPackage(String str, String[] strArr) {
        j jVarC = m.c();
        jVarC.a(str, strArr);
        m.a(jVarC);
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
        return ((r) this).i.subSequence(getSelectionStart(), getSelectionEnd() - getSelectionStart()).toString();
    }

    public g getText() {
        return createDocumentProvider();
    }

    public void gotoLine() {
        startGotoMode();
    }

    public void gotoLine(int i) {
        if (i > ((r) this).i.f()) {
            i = ((r) this).i.f();
        }
        setSelection(getText().c(i - 1));
    }

    public void insert(int i, String str) {
        selectText(false);
        moveCaret(i);
        paste(str);
    }

    /* JADX WARN: Multi-variable type inference failed */
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
        return super/*android.view.View*/.onKeyShortcut(i, keyEvent);
    }

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

    /* JADX WARN: Multi-variable type inference failed */
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

    /* JADX WARN: Multi-variable type inference failed */
    public void removePackage(String str) {
        j jVarC = m.c();
        jVarC.g(str);
        m.a(jVarC);
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

    public void setBackgroundColor(int i) {
        getColorScheme().a(c.a.b, i);
    }

    public void setBasewordColor(int i) {
        getColorScheme().a(c.a.l, i);
    }

    public void setCommentColor(int i) {
        getColorScheme().a(c.a.j, i);
    }

    public void setDark(boolean z) {
        setColorScheme(z ? new d() : new e());
    }

    public void setKeywordColor(int i) {
        getColorScheme().a(c.a.k, i);
    }

    public void setPanelBackgroundColor(int i) {
        ((r) this).t.a(i);
    }

    public void setPanelTextColor(int i) {
        ((r) this).t.b(i);
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
        getColorScheme().a(c.a.n, i);
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
        getColorScheme().a(c.a.a, i);
    }

    public void setTextHighlightColor(int i) {
        getColorScheme().a(c.a.d, i);
    }

    public void setUserwordColor(int i) {
        getColorScheme().a(c.a.m, i);
    }

    public void setWordWrap(boolean z) {
        this.ka = z;
        super.setWordWrap(z);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public void startFindMode() {
        startActionMode(new ActionMode.Callback() { // from class: com.androlua.LuaEditor.2
            private n a;
            private int b;
            private EditText c;

            private void a() {
                this.a = new n();
                String string = this.c.getText().toString();
                if (string.isEmpty()) {
                    LuaEditor.this.selectText(false);
                    return;
                }
                this.b = this.a.a(LuaEditor.this.getText(), string, this.b, LuaEditor.this.getText().length(), false, false);
                int i = this.b;
                if (i == -1) {
                    LuaEditor.this.selectText(false);
                    Toast.makeText(LuaEditor.this.la, "\u672a\u627e\u5230", 0).show();
                    this.b = 0;
                } else {
                    LuaEditor.this.setSelection(i, this.c.getText().length());
                    this.b += this.c.getText().length();
                    LuaEditor.this.moveCaret(this.b);
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
                this.c = new EditText(LuaEditor.this.la) { // from class: com.androlua.LuaEditor.2.1
                    @Override // android.widget.TextView
                    public void onTextChanged(CharSequence charSequence, int i, int i2, int i3) {
                        if (charSequence.length() > 0) {
                            AnonymousClass2.this.b = 0;
                            a();
                        }
                    }
                };
                this.c.setSingleLine(true);
                this.c.setImeOptions(3);
                this.c.setOnEditorActionListener(new TextView.OnEditorActionListener() { // from class: com.androlua.LuaEditor.2.2
                    @Override // android.widget.TextView.OnEditorActionListener
                    public boolean onEditorAction(TextView textView, int i, KeyEvent keyEvent) {
                        a();
                        return true;
                    }
                });
                this.c.setLayoutParams(new RadioGroup.LayoutParams(LuaEditor.this.getWidth() / 3, -1));
                menu.add(0, 1, 0, BuildConfig.FLAVOR).setActionView(this.c);
                menu.add(0, 2, 0, LuaEditor.this.la.getString(android.R.string.search_go));
                this.c.requestFocus();
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

    /* JADX WARN: Multi-variable type inference failed */
    public void startGotoMode() {
        startActionMode(new ActionMode.Callback() { // from class: com.androlua.LuaEditor.1
            private int a;
            private EditText b;

            private void a() {
                String string = this.b.getText().toString();
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
                this.b = new EditText(LuaEditor.this.la) { // from class: com.androlua.LuaEditor.1.1
                    @Override // android.widget.TextView
                    public void onTextChanged(CharSequence charSequence, int i, int i2, int i3) {
                        if (charSequence.length() > 0) {
                            AnonymousClass1.this.a = 0;
                            a();
                        }
                    }
                };
                this.b.setSingleLine(true);
                this.b.setInputType(2);
                this.b.setImeOptions(2);
                this.b.setOnEditorActionListener(new TextView.OnEditorActionListener() { // from class: com.androlua.LuaEditor.1.2
                    @Override // android.widget.TextView.OnEditorActionListener
                    public boolean onEditorAction(TextView textView, int i, KeyEvent keyEvent) {
                        a();
                        return true;
                    }
                });
                this.b.setLayoutParams(new RadioGroup.LayoutParams(LuaEditor.this.getWidth() / 3, -1));
                menu.add(0, 1, 0, BuildConfig.FLAVOR).setActionView(this.b);
                menu.add(0, 2, 0, LuaEditor.this.la.getString(android.R.string.ok));
                this.b.requestFocus();
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

    /* JADX WARN: Multi-variable type inference failed */
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