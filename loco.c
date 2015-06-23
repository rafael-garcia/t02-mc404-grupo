#include "api_robot2.h"

void _start(void) {
	set_motor_speed(10,0);
}

/* Spend some time doing nothing. */
void delay() {
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 10000; i++ );
}		
