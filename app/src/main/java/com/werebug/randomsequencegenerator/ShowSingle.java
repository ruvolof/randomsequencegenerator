package com.werebug.randomsequencegenerator;

import android.os.Build;
import android.os.Bundle;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

public class ShowSingle extends Activity implements OnClickListener {

    // TextView to set output
    private TextView show;

    // Buttons
    private Button copy, send;

    // Intent to send sequence
    private Intent send_to = new Intent(Intent.ACTION_SEND);

    // The sequence showed
    private String sequence;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_show_single);

        // Finding show TextView
        this.show = (TextView)findViewById(R.id.show);

        // Finding Buttons and adding onClickListener
        this.copy = (Button)findViewById(R.id.copy_button);
        this.send = (Button)findViewById(R.id.send_button);
        this.copy.setOnClickListener(this);
        this.send.setOnClickListener(this);

        // Retrieving arguments
        this.sequence = this.getIntent().getExtras().getString("seq_to_show");

        // Setting show TextView text to the string
        this.show.setText(this.sequence);
    }

    @SuppressWarnings("deprecation")
    @SuppressLint("NewApi")
    public void onClick (View v) {
        switch (v.getId()) {
            case R.id.copy_button:
                int sdk = Build.VERSION.SDK_INT;
                if (sdk >= 11) {
                    ClipboardManager clipboard = (ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
                    ClipData clip = ClipData.newPlainText("rgs", this.sequence);
                    clipboard.setPrimaryClip(clip);
                }
                else {
                    android.text.ClipboardManager old_cbm = (android.text.ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
                    old_cbm.setText(this.sequence);
                }
                Toast.makeText(this, R.string.copied_to_cb, Toast.LENGTH_SHORT).show();
                break;

            case R.id.send_button:
                this.send_to.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
                this.send_to.setType("text/plain");
                this.send_to.putExtra(Intent.EXTRA_TEXT, this.sequence);
                startActivity(Intent.createChooser(this.send_to, getResources().getString(R.string.send)));
                break;

        }
    }

}
