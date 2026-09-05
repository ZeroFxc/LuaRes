package base64.luacparse;

import base64.luacparse.decompile.FileOutputProvider;
import base64.luacparse.decompile.Output;
import java.io.FileOutputStream;
import java.io.IOException;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class Configuration {
    public Mode mode;
    public String opmap;
    public String output;
    public boolean rawstring;
    public boolean strict_scope;
    public VariableMode variable;

    public enum Mode {
        DECOMPILE,
        DISASSEMBLE,
        ASSEMBLE
    }

    public enum VariableMode {
        NODEBUG,
        DEFAULT,
        FINDER
    }

    public Configuration() {
        this.rawstring = false;
        this.mode = Mode.DECOMPILE;
        this.variable = VariableMode.DEFAULT;
        this.strict_scope = false;
        this.opmap = null;
        this.output = null;
    }

    public Configuration(Configuration other) {
        this.rawstring = other.rawstring;
        this.mode = other.mode;
        this.variable = other.variable;
        this.strict_scope = other.strict_scope;
        this.opmap = other.opmap;
        this.output = other.output;
    }

    public Output getOutput() {
        if (this.output != null) {
            try {
                return new Output(new FileOutputProvider(new FileOutputStream(this.output)));
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }
        return new Output();
    }
}