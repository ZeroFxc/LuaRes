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

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaDialog extends AlertDialog implements DialogInterface.OnClickListener {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private Context f777a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private ListView f778b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private String f779c;
    private String d;
    private View e;
    private OnClickListener f;

    public interface OnClickListener {
        void onClick(LuaDialog luaDialog, Button button);
    }

    public LuaDialog(Context context) {
        super(context);
        this.f777a = context;
        this.f778b = new ListView(this.f777a);
    }

    public LuaDialog(Context context, int i) {
        super(context, i);
        this.f777a = context;
        this.f778b = new ListView(this.f777a);
    }

    @Override // android.app.AlertDialog
    public ListView getListView() {
        return this.f778b;
    }

    public String getMessage() {
        return this.f779c;
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
        if (!this.f778b.equals(this.e)) {
            setView(this.f778b);
        }
        this.f778b.setAdapter(listAdapter);
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
        setAdapter(new ArrayListAdapter(this.f777a, android.R.layout.simple_list_item_1, new ArrayList(Arrays.asList(strArr))));
        this.f778b.setChoiceMode(0);
    }

    @Override // android.app.AlertDialog
    public void setMessage(CharSequence charSequence) {
        this.f779c = charSequence.toString();
        super.setMessage(charSequence);
    }

    public void setMultiChoiceItems(CharSequence[] charSequenceArr) {
        setMultiChoiceItems(charSequenceArr, new int[0]);
    }

    public void setMultiChoiceItems(CharSequence[] charSequenceArr, int[] iArr) {
        setAdapter(new ArrayListAdapter(this.f777a, android.R.layout.simple_list_item_multiple_choice, new ArrayList(Arrays.asList(charSequenceArr))));
        this.f778b.setChoiceMode(2);
        for (int i : iArr) {
            this.f778b.setItemChecked(i, true);
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
        this.f778b.setOnItemClickListener(onItemClickListener);
    }

    public void setOnItemLongClickListener(AdapterView.OnItemLongClickListener onItemLongClickListener) {
        this.f778b.setOnItemLongClickListener(onItemLongClickListener);
    }

    public void setOnItemSelectedListener(AdapterView.OnItemSelectedListener onItemSelectedListener) {
        this.f778b.setOnItemSelectedListener(onItemSelectedListener);
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
        setAdapter(new ArrayListAdapter(this.f777a, android.R.layout.simple_list_item_single_choice, new ArrayList(Arrays.asList(charSequenceArr))));
        this.f778b.setChoiceMode(1);
        this.f778b.setItemChecked(i, true);
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