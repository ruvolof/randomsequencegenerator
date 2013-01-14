package com.werebug.randomsequencegenerator;

import java.util.ArrayList;
import java.util.Map;

import android.os.Bundle;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;

public class ShowSaved extends FragmentActivity implements OnItemClickListener, ConfirmDeleteAllDialog.ConfirmDeleteAllListener {
	
	// Layout
	private ListView add_here;
	private TextView empty_view;
	
	// String Array
	private ArrayList<String> string = new ArrayList<String>();
	
	// SharedPreferences object and editor
	private SharedPreferences sp;
	
	// Array adapter for ListView add_here
	private ArrayAdapter<String> saved;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		
		this.setContentView(R.layout.activity_show_saved);
		
		this.add_here = (ListView)findViewById(R.id.saved_list);
		this.empty_view = (TextView)findViewById(R.id.empty_text);
		
		// Loading shared preferences and editor
		this.sp = this.getSharedPreferences("saved_sequences", MODE_PRIVATE);
		
		// Creating the Adapter with all strings in an array
		this.saved = new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, android.R.id.text1, string);
		this.saved.setNotifyOnChange(true);
		
		// Retrieving all pairs in SharedPreferences sp
		Map<String, ?> kv = sp.getAll();
		
		// Iterating through shared preferences
		for(Map.Entry<String, ?> entry : kv.entrySet()) {		
			saved.add(entry.getKey());
		}
		
		// Setting Adapter to ListView and empty View
		this.add_here.setEmptyView(empty_view);
		this.add_here.setAdapter(this.saved);
		
		// Setting Listener for ListView add_here
		this.add_here.setOnItemClickListener(this);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.activity_show_saved, menu);
		return true;
	}
	
	public void onItemClick (AdapterView<?> adapter, View view, int pos, long id) {
		return;
	}
	
	public boolean onOptionsItemSelected (MenuItem mi){
		switch (mi.getItemId()){
			case R.id.menu_delete_all:
				DialogFragment newFragment = new ConfirmDeleteAllDialog();
    		    newFragment.show(getSupportFragmentManager(), "confirm_delete_all");
				return true;
				
			default:
				return super.onOptionsItemSelected(mi);
		}
	}
	
	// Implementing method from ConfirmDeleteAllDialog.onConfirmDeleteAllListener
	public void onConfirmDeleteAllPositive (DialogFragment dialog) {
		// Erasing entries from SharedPreferences
		Editor ed = (Editor)this.sp.edit();
		ed.clear();
		ed.commit();
		
		// Erasing entries from ListView
		this.saved.clear();
	}
	
	public void onConfirmDeleteAllNegative (DialogFragment dialog) {
		return;
	}

}
