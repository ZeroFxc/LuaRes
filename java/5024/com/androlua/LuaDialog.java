package com.androlua;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.graphics.drawable.Drawable;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayListAdapter;
import android.widget.Button;
import android.widget.ListAdapter;
import android.widget.ListView;
import java.util.ArrayList;
import java.util.Arrays;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaDialog extends AlertDialog implements DialogInterface.OnClickListener {
    private Context a;
    private ListView b;
    private String c;
    private String d;
    private View e;
    private OnClickListener f;

    public interface OnClickListener {
        void onClick(LuaDialog luaDialog, Button button);
    }

    public LuaDialog(Context context) {
        super(context);
        this.a = context;
        this.b = new ListView(this.a);
    }

    public LuaDialog(Context context, int i) {
        super(context, i);
        this.a = context;
        this.b = new ListView(this.a);
    }

    @Override // android.app.AlertDialog
    public ListView getListView() {
        return this.b;
    }

    public String getMessage() {
        return this.c;
    }

    public String getTitle() {
        return this.d;
    }

    public View getView() {
        return this.e;
    }

    @Override // android.app.Dialog
    public void hide() {
        super.hide();
    }

    @Override // android.app.Dialog
    public boolean isShowing() {
        return super.isShowing();
    }

    @Override // android.content.DialogInterface.OnClickListener
    public void onClick(DialogInterface dialogInterface, int i) {
        OnClickListener onClickListener = this.f;
        if (onClickListener != null) {
            onClickListener.onClick(this, getButton(i));
        }
    }

    public void setAdapter(ListAdapter listAdapter) {
        if (!this.b.equals(this.e)) {
            setView(this.b);
        }
        this.b.setAdapter(listAdapter);
    }

    public void setButton(CharSequence charSequence) {
        setOkButton(charSequence);
    }

    public void setButton1(CharSequence charSequence) {
        setButton(-1, charSequence, this);
    }

    public void setButton2(CharSequence charSequence) {
        setButton(-2, charSequence, this);
    }

    public void setButton3(CharSequence charSequence) {
        setButton(-3, charSequence, this);
    }

    public void setCancelButton(CharSequence charSequence) {
        setButton(-2, charSequence, this);
    }

    @Override // android.app.AlertDialog
    public void setIcon(Drawable drawable) {
        super.setIcon(drawable);
    }

    public void setItems(String[] strArr) {
        setAdapter(new ArrayListAdapter(this.a, android.R.layout.simple_list_item_1, new ArrayList(Arrays.asList(strArr))));
        this.b.setChoiceMode(0);
    }

    @Override // android.app.AlertDialog
    public void setMessage(CharSequence charSequence) {
        this.c = charSequence.toString();
        super.setMessage(charSequence);
    }

    public void setMultiChoiceItems(CharSequence[] charSequenceArr) {
        setMultiChoiceItems(charSequenceArr, new int[0]);
    }

    public void setMultiChoiceItems(CharSequence[] charSequenceArr, int[] iArr) {
        setAdapter(new ArrayListAdapter(this.a, android.R.layout.simple_list_item_multiple_choice, new ArrayList(Arrays.asList(charSequenceArr))));
        this.b.setChoiceMode(2);
        for (int i : iArr) {
            this.b.setItemChecked(i, true);
        }
    }

    public void setNegButton(CharSequence charSequence) {
        setButton(-2, charSequence, this);
    }

    public void setNegativeButton(CharSequence charSequence, DialogInterface.OnClickListener onClickListener) {
        setButton(-2, charSequence, onClickListener);
    }

    public void setNeuButton(CharSequence charSequence) {
        setButton(-3, charSequence, this);
    }

    public void setNeutralButton(CharSequence charSequence, DialogInterface.OnClickListener onClickListener) {
        setButton(-3, charSequence, onClickListener);
    }

    public void setOkButton(CharSequence charSequence) {
        setButton(-1, charSequence, this);
    }

    @Override // android.app.Dialog
    public void setOnCancelListener(DialogInterface.OnCancelListener onCancelListener) {
        super.setOnCancelListener(onCancelListener);
    }

    public void setOnClickListener(OnClickListener onClickListener) {
        this.f = onClickListener;
    }

    @Override // android.app.Dialog
    public void setOnDismissListener(DialogInterface.OnDismissListener onDismissListener) {
        super.setOnDismissListener(onDismissListener);
    }

    public void setOnItemClickListener(AdapterView.OnItemClickListener onItemClickListener) {
        this.b.setOnItemClickListener(onItemClickListener);
    }

    public void setOnItemLongClickListener(AdapterView.OnItemLongClickListener onItemLongClickListener) {
        this.b.setOnItemLongClickListener(onItemLongClickListener);
    }

    public void setOnItemSelectedListener(AdapterView.OnItemSelectedListener onItemSelectedListener) {
        this.b.setOnItemSelectedListener(onItemSelectedListener);
    }

    public void setPosButton(CharSequence charSequence) {
        setButton(-1, charSequence, this);
    }

    public void setPositiveButton(CharSequence charSequence, DialogInterface.OnClickListener onClickListener) {
        setButton(-1, charSequence, onClickListener);
    }

    public void setSingleChoiceItems(CharSequence[] charSequenceArr) {
        setSingleChoiceItems(charSequenceArr, 0);
    }

    public void setSingleChoiceItems(CharSequence[] charSequenceArr, int i) {
        setAdapter(new ArrayListAdapter(this.a, android.R.layout.simple_list_item_single_choice, new ArrayList(Arrays.asList(charSequenceArr))));
        this.b.setChoiceMode(1);
        this.b.setItemChecked(i, true);
    }

    @Override // android.app.AlertDialog, android.app.Dialog
    public void setTitle(CharSequence charSequence) {
        this.d = charSequence.toString();
        super.setTitle(charSequence);
    }

    @Override // android.app.AlertDialog
    public void setView(View view) {
        this.e = view;
        super.setView(view);
    }

    @Override // android.app.Dialog
    public void show() {
        super.show();
    }
}