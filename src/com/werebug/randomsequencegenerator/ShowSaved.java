package com.werebug.randomsequencegenerator;

import java.util.Map;

import android.os.Bundle;
import android.app.Activity;
import android.content.SharedPreferences;
import android.view.Menu;
import android.widget.LinearLayout;
import android.widget.LinearLayout.LayoutParams;
import android.widget.TextView;

public class ShowSaved extends Activity {
	
	// Layout
	private LinearLayout add_here;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		
		this.setContentView(R.layout.activity_show_saved);
		
		this.add_here = (LinearLayout)findViewById(R.id.saved_list);
		
		// Loading shared preferences
		SharedPreferences sp = this.getPreferences(MODE_PRIVATE);
		Map<String, ?> kv = sp.getAll();
		
		int i = 0;
		// Iterating through shared preferences
		for(Map.Entry<String, ?> entry : kv.entrySet()) {
			TextView to_add = new TextView(this);
			to_add.setText(entry.getKey());
			to_add.setId(i++);
			this.add_here.addView(to_add, LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
		}
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.activity_show_saved, menu);
		return true;
	}

}
