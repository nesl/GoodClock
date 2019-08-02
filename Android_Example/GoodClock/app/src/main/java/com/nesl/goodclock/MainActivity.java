package com.nesl.goodclock;

import androidx.appcompat.app.AppCompatActivity;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.nesl.ntp.GoodClock;

public class MainActivity extends AppCompatActivity {

    /*
    Used to get the offset and the correct current time
     */
    GoodClock goodClock;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Button GetTime = (Button)findViewById(R.id.GetTime);
        final TextView timeUpdate = (TextView)findViewById(R.id.timeUpdate);


        //Starting the GoodClock library
        try{
            goodClock = new GoodClock();
            goodClock.start();
        }
        catch (Exception e)
        {
            e.printStackTrace();
        }


        //updating the time on click of the button
        GetTime.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {

                //to avoid the exception crashes if at all
                try{

                    if(goodClock.SntpSuceeded) //NTP has succeded
                    {
                        long ntp_error = goodClock.getNtp_clockoffset();
                        long curr_time = goodClock.Now();
                        String output ="Time is in milliseconds";
                        output=output +"\nTime Error: "+ntp_error+"\nCorrected Time: "+curr_time+"\nSystem Time: "+System.currentTimeMillis();
                        timeUpdate.setText(output);

                    }
                    else
                    {
                        String output = "NTP has not succeeded yet";
                        timeUpdate.setText(output);
                    }


                }
                catch (Exception e)
                {

                    e.printStackTrace();
                }

            }
        });




    }//end onCreate
}//end MainActivity
