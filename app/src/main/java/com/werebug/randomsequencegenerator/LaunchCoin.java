package com.werebug.randomsequencegenerator;

import android.os.Bundle;
import android.os.CountDownTimer;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;
import android.app.Activity;

public class LaunchCoin extends Activity implements OnClickListener {

    private Button flip;
    private final int MAXFLIP = 30;
    private final int MINFLIP = 10;
    private final long SLEEP = 200;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_launch_coin);

        this.flip = (Button)findViewById(R.id.launch_button);

        this.flip.setOnClickListener(this);
    }

    public void onClick(View v) {
        int clicked = v.getId();

        switch(clicked) {

            case R.id.launch_button:

                int flipnum = (int)Math.round(Math.random() * (MAXFLIP - MINFLIP) + MINFLIP);

                CountDownTimer timer = new CountDownTimer(flipnum * SLEEP, SLEEP) {

                    private TextView result = (TextView)findViewById(R.id.coin_result);
                    private int i = 0;
                    private int coin = (int)Math.round(Math.random());

                    @Override
                    public void onFinish() {
                        result.setText(Integer.toString(this.coin));
                    }

                    @Override
                    public void onTick(long millisUntilFinished) {
                        if (i == 0) {
                            result.setTextColor(getResources().getColor(R.color.text_color));
                            result.setTextSize(getResources().getDimension(R.dimen.coin_text_size));
                        }
                        result.setText(Integer.toString(this.i % 2));
                        i++;
                    }

                };

                timer.start();

                break;

            default:
                break;
        }
    }

}
