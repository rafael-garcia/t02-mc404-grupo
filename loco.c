#include "api_robot2.h"

void delay();

int i = 30;

void _start(void) {
	int a = 0;
	set_motors_speed(30,30);
	i = 0;
	while(1){
		if(read_sonar(4) < 2000){
			set_motor_speed(10,1);
		}
	}
}

/* Spend some time doing nothing. */
void delay() {
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 900; i++ ){
  }

}		
