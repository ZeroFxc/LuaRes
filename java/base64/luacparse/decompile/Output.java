package base64.luacparse.decompile;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class Output {
    private int indentationLevel;
    private OutputProvider out;
    private int position;

    public Output() {
        this(new OutputProvider() { // from class: base64.luacparse.decompile.Output.1
            @Override // base64.luacparse.decompile.OutputProvider
            public void print(String s) {
                System.out.print(s);
            }

            @Override // base64.luacparse.decompile.OutputProvider
            public void print(byte b) {
                System.out.write(b);
            }

            @Override // base64.luacparse.decompile.OutputProvider
            public void println() {
                System.out.println();
            }
        });
    }

    public Output(OutputProvider out) {
        this.indentationLevel = 0;
        this.position = 0;
        this.out = out;
    }

    public void indent() {
        this.indentationLevel += 2;
    }

    public void dedent() {
        this.indentationLevel -= 2;
    }

    public int getIndentationLevel() {
        return this.indentationLevel;
    }

    public int getPosition() {
        return this.position;
    }

    public void setIndentationLevel(int indentationLevel) {
        this.indentationLevel = indentationLevel;
    }

    private void start() {
        if (this.position == 0) {
            for (int i = this.indentationLevel; i != 0; i--) {
                this.out.print(" ");
                this.position++;
            }
        }
    }

    public void print(String s) {
        start();
        for (int i = 0; i < s.length(); i++) {
            this.out.print((byte) s.charAt(i));
        }
        this.position += s.length();
    }

    public void print(byte b) {
        start();
        this.out.print(b);
        this.position++;
    }

    public void println() {
        start();
        this.out.println();
        this.position = 0;
    }

    public void println(String s) {
        print(s);
        println();
    }
}