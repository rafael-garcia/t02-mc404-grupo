#include "api_robot2.h"

void delay();
void busca_parede();
void segue_parede();

void _start(void) {
	busca_parede();
	while (1) {
		segue_parede();
	}
}

/**
	Uoli anda em linha reta, sem colidir, ate encontrar uma parede a sua frente.
*/
void busca_parede() {
	unsigned int girador = 0;
	unsigned int sonar3 = 0;
	unsigned int sonar4 = 0;
	sonar3 = read_sonar(3);
	sonar4 = read_sonar(4);

	if (sonar3 > 1200 && sonar4 > 1200) {
		set_motors_speed(30,30);
	}
	while (sonar3 > 1200 && sonar4 > 1200) {	
		sonar3 = read_sonar(3);
		sonar4 = read_sonar(4);
	}
	// ja esta proximo

	while (girador < 25) {
		set_motors_speed(0,10);
		girador++;
	}
}

void segue_parede() {
	set_motors_speed(20,20);
}

/* Spend some time doing nothing. */
void delay() {
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 900; i++ ){
  }

}		
