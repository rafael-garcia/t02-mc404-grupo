#include "api_robot2.h"

void delay();

void _start(void) {
	int a = 0;
	set_motors_speed(20,50);
}

/* Spend some time doing nothing. */
void delay() {
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 4; i++ );

}		
