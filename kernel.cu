#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdlib.h> 
#include <stdio.h>
#include <iostream>
#include <curand_kernel.h>
#include <time.h>
#include <device_functions.h>
#include <cuda.h>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"



__global__ void movimientoDerecha(float* tablero, int nf, int nc) {
	int id = threadIdx.x * nf;
	int posicion = nc-1; //nos movemos a través de las columnas de la misma fila 
	int comparador = nc-2;
	int cursor = nc-1;
	while (posicion >= 0 && comparador > -1) {
		//si no se ha llegado al final y ambos números son iguales y distintos de 0 se suman 
		if (posicion > 0 && tablero[id+posicion] == tablero[id+comparador] && tablero[id +posicion] != 0
			&& tablero[id+comparador] != 0) {
			int suma = tablero[id + comparador] + tablero[id +posicion];
			tablero[id+posicion] = 0;
			tablero[id +comparador] = 0;
			tablero[id +cursor] = suma;
			cursor--;
			posicion = comparador - 1;
			comparador -= 2;
			
		}
		//si donde nos encontramos es 0
		else if (tablero[id +posicion] == 0) {
			posicion--;
			comparador--;
		} //si el contiguo es 0
		else if (tablero[id +comparador] == 0) {
			comparador--;
		}
		else { // Ambos son diferentes de cero y diferentes entre si
			int aux = tablero[id + posicion] = 0;
			tablero[id+posicion] = 0;
			tablero[id + cursor] = aux;
			cursor--;
			posicion = comparador;
			comparador--;
		}
	}
	if (posicion >= 0) {
		int aux = tablero[id+posicion];
		tablero[id+posicion] = 0;
		tablero [id+cursor] = aux;

	}
}
	


__global__ void movimientoArriba(float* tablero, int nf, int nc) {
	int id = threadIdx.x * nf;
	int posicion = 0;
	int comparador = posicion + nc;
	int cursor = 0;
	int size = nc*nf;

	while (posicion <= (nf-1) && comparador < size) {
		if (posicion < (nf-1) && tablero[posicion + id] == tablero[comparador + id] && tablero[posicion + id] != 0
			&& tablero[comparador + id] != 0) {
			int suma = tablero[comparador + id] + tablero[posicion + id];
			tablero[posicion + id] = 0;
			tablero[comparador + id] = 0;
			tablero[cursor + id] = suma;
			cursor++;
			posicion = posicion + 1;
			comparador++;
			
		}
		else if (tablero[posicion + id] == 0) {
			posicion++;
			comparador++;
		}
		else if (tablero[comparador + id] == 0) {
			comparador+nc;
		}
		else { // Ambos son diferentes de cero y diferentes entre
			   // si
			int aux = tablero[posicion +id];
			tablero[posicion + id] = 0;
			tablero[cursor + id] = aux;
			cursor += nc; //curso en la misma columna de la fila de abajo
			posicion = comparador;
			comparador += nc;
		}
	}
	if (posicion <= (nf-1)) {
		int aux = tablero[posicion + id];
		tablero[posicion + id] = 0;
		tablero[cursor + id] = aux;

	}
}
	
