package com.werebug.randomsequencegenerator;

import com.werebug.randomsequencegenerator.R;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.RadioGroup;
import android.widget.RadioGroup.OnCheckedChangeListener;
import android.widget.TextView;
import android.widget.Toast;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;

public class Rsg_main extends Activity implements OnClickListener, OnCheckedChangeListener {
	
	// Layout widgets
	private View range_layout, manual_layout, copy_send;
	private Button create, copy, send_to;
	private CheckBox digit, lowercase, uppercase, special;
	private RadioGroup rg;
	private TextView manual, length_textview, output;
	
	// String used to generate the random sequence
	private final String BINARY = "01";
	private final String HEX = "0123456789ABCDEF";
	private final String DIGIT = "0123456789";
	private final String LAZ = "qwertyuiopasdfghjklzxcvbnm";
	private final String CAZ = "QWERTYUIOPASDFGHJKLZXCVBNM";
	private final String SPECIAL = "$%&()=?@#<>_£[]*";
	
	// Intent to send text to other apps
	private Intent send_to_intent = new Intent(Intent.ACTION_SEND);

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_rsg_main);
        
        // Retrieving layout
        this.range_layout = (View)findViewById(R.id.class_range);
    	this.manual_layout = (View)findViewById(R.id.manual_layout);
    	this.copy_send = (View)findViewById(R.id.copy_send);
    	
    	
    	// Retrieving CheckBox
    	this.digit = (CheckBox)findViewById(R.id.range_digit);
		this.lowercase = (CheckBox)findViewById(R.id.range_lowercase);
		this.uppercase = (CheckBox)findViewById(R.id.range_uppercase);
		this.special = (CheckBox)findViewById(R.id.range_special);
		
		// Retrieving TextView
		this.manual = (TextView)findViewById(R.id.manual);
		this.length_textview = (TextView)findViewById(R.id.string_length);
    	this.output = (TextView)findViewById(R.id.output_textview);


        // Setting Listener for buttons
        this.create = (Button)findViewById(R.id.button_create);
        this.create.setOnClickListener(this);
        
        this.copy = (Button)findViewById(R.id.copy_button);
        this.copy.setOnClickListener(this);
        
        this.send_to = (Button)findViewById(R.id.send_button);
        this.send_to.setOnClickListener(this);
        
        // Setting listener for RadioGroup
        this.rg = (RadioGroup)findViewById(R.id.radio_group);
        this.rg.setOnCheckedChangeListener(this);
    }
    
    // Implements OnCheckedChangeListener
    // This functions hides and shows widget depending on situation
    public void onCheckedChanged (RadioGroup rg, int newchecked) {
    	switch (newchecked) {
    		case R.id.class_radio:
    			this.range_layout.setVisibility(View.VISIBLE);		
    			this.manual_layout.setVisibility(View.GONE);
    			break;
    		case R.id.manual_radio:
    			this.manual_layout.setVisibility(View.VISIBLE);
    			this.range_layout.setVisibility(View.GONE);	
    			break;
    		default:
    			this.manual_layout.setVisibility(View.GONE);
    			this.range_layout.setVisibility(View.GONE);
    	}
    }
    
    @SuppressLint("NewApi")
	@SuppressWarnings("deprecation")
	public void onClick (View v) {
    	int clicked = v.getId();
    	switch (clicked) {
    		case R.id.button_create:
    			String chars = "";
    			String result = "";
    			
    	    	int selected = this.rg.getCheckedRadioButtonId();
    	    	
    	    	switch (selected) {
    	    		case R.id.binary_radio:
    	    			chars = chars.concat(this.BINARY);
    	    			break;
    	    			
    	    		case R.id.hex_radio:
    	    			chars = chars.concat(this.HEX);
    	    			break;
    	    			
    	    		case R.id.class_radio:
    	    			if (this.digit.isChecked()) {
    	    				chars = chars.concat(this.DIGIT);
    	    			}
    	    			if (this.lowercase.isChecked()) {
    	    				chars = chars.concat(this.LAZ);
    	    			}
    	    			if (this.uppercase.isChecked()) {
    	    				chars = chars.concat(this.CAZ);
    	    			}
    	    			if (this.special.isChecked()) {
    	    				chars = chars.concat(this.SPECIAL);
    	    			}
    	    			break;
    	    			
    	    		case R.id.manual_radio:
    	    			String chars_to_add = this.manual.getText().toString();
    	    			chars = chars.concat(chars_to_add);
    	    			break;
    	    		
    	    		default:
    	    			break;
    	    	}
    	    	
    	    	int chars_last_index = chars.length() - 1;
    	    	
    	    	if (chars_last_index >= 0) {
    	    		this.copy_send.setVisibility(View.VISIBLE);
    	    		
    	    		// Converting length to integer
	    	    	String length_as_string = this.length_textview.getText().toString();
	    	    	int selected_length = Integer.parseInt(length_as_string, 10);
	    	    	
	    	    	// Generating the string
	    	    	for (int i = selected_length; i > 0; i--) {
	    	    		long random = Math.round(Math.random()*chars_last_index);
	    	    		int index = (int) random;
	    	    		String to_concat = String.valueOf(chars.charAt(index));
	    	    		result = result.concat(to_concat);
	    	    	}
    	    	}
    	    	else {
    	    		this.copy_send.setVisibility(View.GONE);
    	    	}
    	    	
    	    	output.setText(result);
    	    	break;
    	    	
    		case R.id.copy_button:
    			int sdk = Build.VERSION.SDK_INT;
    			if (sdk >= 11) {
	    			ClipboardManager clipboard = (ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
	    			ClipData clip = ClipData.newPlainText("rgs", this.output.getText());
	    			clipboard.setPrimaryClip(clip);
    			}
    			else {
					android.text.ClipboardManager old_cbm = (android.text.ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
    				old_cbm.setText(this.output.getText());    				
    			}
    			Toast.makeText(this, R.string.copied_to_cb, Toast.LENGTH_SHORT).show();
    			break;
    		
    		case R.id.send_button:
    			this.send_to_intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
    			this.send_to_intent.setType("text/plain");
    			this.send_to_intent.putExtra(Intent.EXTRA_TEXT, this.output.getText());
    			startActivity(Intent.createChooser(this.send_to_intent, getResources().getString(R.string.send_with)));
    			break;
    	    
    	    default:
    	    	break;
    	}
    }
}
