package com.werebug.randomsequencegenerator;

import java.util.ArrayList;
import java.util.Map;

import android.os.Bundle;
import android.annotation.SuppressLint;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.AdapterContextMenuInfo;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;
import android.os.*;
import android.content.*;

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
	
	// Intent to send with
	private Intent send_to = new Intent(Intent.ACTION_SEND);

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
		
		// Setting context menu to ListView item
		this.registerForContextMenu(this.add_here);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.activity_show_saved, menu);
		return true;
	}
	
	public boolean onOptionsItemSelected (MenuItem mi){
		switch (mi.getItemId()){
			case R.id.menu_delete_all:
				if (!this.saved.isEmpty()) {
					DialogFragment newFragment = new ConfirmDeleteAllDialog();
	    		    newFragment.show(getSupportFragmentManager(), "confirm_delete_all");
				}
				else {
					Toast.makeText(this, R.string.nothing_to_delete, Toast.LENGTH_SHORT).show();
				}
				return true;
				
			default:
				return super.onOptionsItemSelected(mi);
		}
	}
	
	@Override
	public void onCreateContextMenu(ContextMenu menu, View view, ContextMenuInfo menuInfo) {
		super.onCreateContextMenu(menu, view, menuInfo);
		
		// Inflating menu layout
		MenuInflater inflater = this.getMenuInflater();
		inflater.inflate(R.menu.show_saved_conmenu, menu);
	}
	
	// Implementing onItemClick required for OnItemClickListener
	public void onItemClick (AdapterView<?> adapter, View view, int pos, long id) {
		return;
	}
	
	@SuppressWarnings("deprecation")
	@SuppressLint("NewApi")
	@Override
	public boolean onContextItemSelected(MenuItem item){
		AdapterContextMenuInfo saved = (AdapterContextMenuInfo) item.getMenuInfo();

		String key = ((TextView)saved.targetView).getText().toString();
		
		// Retrieving string value from SharedPreferences
		String val = sp.getString(key, "null");

		switch (item.getItemId()){
			case R.id.conmenu_delete:
				// Removing key from editor
				Editor ed = this.sp.edit();
				ed.remove(key);
				ed.commit();
				
				// Hiding View from ListView
				saved.targetView.setVisibility(View.GONE);
				return true;
				
			case R.id.conmenu_copy:
				if (val.equals("null")) {
					Toast.makeText(this, R.string.string_notfound, Toast.LENGTH_SHORT).show();
				}
				else {
					int sdk = Build.VERSION.SDK_INT;
    				if (sdk >= 11) {
	    				ClipboardManager clipboard = (ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
	    				ClipData clip = ClipData.newPlainText("rgs", val);
	    				clipboard.setPrimaryClip(clip);
    				}
    				else {
						android.text.ClipboardManager old_cbm = (android.text.ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
    					old_cbm.setText(val);    				
    				}
    				Toast.makeText(this, R.string.copied_to_cb, Toast.LENGTH_SHORT).show();	
				}
				return true;
				
			case R.id.conmenu_send:
				this.send_to.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
    			this.send_to.setType("text/plain");
    			this.send_to.putExtra(Intent.EXTRA_TEXT, val);
    			startActivity(Intent.createChooser(this.send_to, getResources().getString(R.string.send)));
				return true;
				
			default:
				return super.onContextItemSelected(item);
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
