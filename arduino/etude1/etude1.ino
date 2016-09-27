
#include "the_synth.h"
  unsigned int counter=0;
  unsigned char bar;
  unsigned int  demo;
  unsigned char midi_state=0;
  unsigned char midi_cmd=0;
  unsigned char midi_1st=0;
  unsigned char midi_2nd=0;
  unsigned char MFLAG=0;

void setup()
{
  Serial.begin(9600);
  initSynth();
  demo = 0;
  bar = 0;


  setup_voice(0,(unsigned int)NoiseTable,200.0,(unsigned int)Env0,0.1,300);
  setup_voice(1,(unsigned int)RampTable,100.0,(unsigned int)Env2,0.5,512);
  setup_voice(2,(unsigned int)SquareTable,100.0,(unsigned int)Env2 ,.4,1000);
  setup_voice(3,(unsigned int)NoiseTable,1200.0,(unsigned int)Env3,.02,500);
}


unsigned char pattern[4][32]=
{
	{1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0},
	{57,0,0,57,0,0,55,0,53,0,52,0,0,0,52,0,0,55,0,0,52,0,0,55,0,51,0,0,51,0,0,51},
	{0,45,0,0,0,45,0,0,0,0,0,0,45,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,45,0,0},
	{0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,57,0}
};

unsigned char song[4][32]=
{
	{0,0,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0},
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
	{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
	{0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1}
};



void loop()
{  
    if(synthTick()) 
    {
      //************************************************
      // Demo mode
      //************************************************
      bar=counter&0x1f;
      demo=counter>>5;

      switch(demo)
      {
        case 2:
        {
          setup_voice(3,(unsigned int)TriangleTable,1500.0,(unsigned int)Env3,.03,100);
        };break;
        case 4:
        {
          setup_voice(3,(unsigned int)NoiseTable, 1500.0, (unsigned int)Env1, 0.2, 100);
        };break;      
        case 7:
        {
          setup_voice(0,(unsigned int)TriangleTable,1500.0,(unsigned int)Env3,.03,100);
          setup_voice(2,(unsigned int)RampTable,100.0,(unsigned int)Env2,1.0,512);
          setup_voice(1,(unsigned int)RampTable,100.0,(unsigned int)Env3,.3,512);
        };break;
        case 8:
        {
          setup_voice(3,(unsigned int)NoiseTable,1500.0,(unsigned int)Env1,.6,300);
          setup_voice(2,(unsigned int)RampTable,100.0,(unsigned int)Env3, 0.3,512);
          setup_voice(1,(unsigned int)SquareTable,100.0,(unsigned int)Env0,0.5,512);
          setup_voice(0,(unsigned int)NoiseTable,200.0,(unsigned int)Env0,0.1,300);
        };break;      
      
        case 12:
        {
          setup_voice(1,(unsigned int)RampTable,100.0,(unsigned int)Env2,0.5,512);
          setup_voice(2,(unsigned int)SquareTable,100.0,(unsigned int)Env3,0.4,512);
        };break;      
      
        case 16:
        {
          setup_voice(1,(unsigned int)SquareTable,100.0,(unsigned int)Env3,1.0,512);
          setup_voice(2,(unsigned int)RampTable,100.0,(unsigned int)Env3, 0.3,512);
          counter=0;
        };break;      
      }

   //   if(song[0][demo])
        if(pattern[0][bar])
          trigger(0);
          
     // if(song[1][demo])
      if(pattern[1][bar])      
        mtrigger(1,pattern[1][bar]);
        
     // if(song[2][demo])
      if(pattern[2][bar])
        mtrigger(2,pattern[2][bar]);
        
     // if(song[3][demo])
      if(pattern[3][bar])
        trigger(3);
        
      Serial.println(counter);
      //************************************************
      // End demo mode
      //************************************************
      tim=0;
      counter++;
     // counter&=0x001f;
    }
}

