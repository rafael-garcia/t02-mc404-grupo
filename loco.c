#include "api_robot2.h"

void _start(void) {
	set_motor_speed(20,0);
	delay();
	set_motor_speed(20,1);
}

/* Spend some time doing nothing. */
void delay() {
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 10000; i++ );
}		