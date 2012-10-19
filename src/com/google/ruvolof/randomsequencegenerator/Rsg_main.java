package com.google.ruvolof.randomsequencegenerator;

import android.os.Bundle;
import android.app.Activity;
import android.view.Menu;

public class Rsg_main extends Activity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_rsg_main);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.activity_rsg_main, menu);
        return true;
    }
}
