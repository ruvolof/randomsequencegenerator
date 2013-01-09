package com.werebug.randomsequencegenerator;

import java.util.ArrayList;
import java.util.Map;

import android.os.Bundle;
import android.app.Activity;
import android.content.SharedPreferences;
import android.util.Log;
import android.view.Menu;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.AdapterView.OnItemLongClickListener;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;

public class ShowSaved extends Activity implements OnItemClickListener, OnItemLongClickListener {
	
	// Layout
	private ListView add_here;
	
	// String Array
	private ArrayList<String> string = new ArrayList<String>();
	
	// Array adapter for ListView add_here
	private ArrayAdapter<String> saved;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		
		this.setContentView(R.layout.activity_show_saved);
		
		this.add_here = (ListView)findViewById(R.id.saved_list);
		
		// Loading shared preferences
		SharedPreferences sp = this.getSharedPreferences("saved_sequences", MODE_PRIVATE);
		Map<String, ?> kv = sp.getAll();
		
		// Iterating through shared preferences
		for(Map.Entry<String, ?> entry : kv.entrySet()) {		
			string.add(entry.getKey());
		}
		
		this.saved = new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, android.R.id.text1, string);
		this.add_here.setAdapter(this.saved);
		
		// Setting Listener for ListView add_here
		this.add_here.setOnItemClickListener(this);
		this.add_here.setOnItemLongClickListener(this);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.activity_show_saved, menu);
		return true;
	}
	
	public void onItemClick (AdapterView<?> adapter, View view, int pos, long id) {
		String s = ((TextView)view).getText().toString();
		Log.d("clicked:", s);
	}
	
	public boolean onItemLongClick (AdapterView<?> adapter, View view, int pos, long id){
		String s = ((TextView)view).getText().toString();
		Log.d("long clicked:", s);
		return true;
	}

}
