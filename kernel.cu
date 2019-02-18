
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdlib.h> 
#include <stdio.h>
#include <curand_kernel.h>
#include <time.h>


#include <curand_kernel.h>
#include <time.h>

#include <curand_kernel.h>
#include <time.h>

/*Función que arranca el kernel y fija el estado de los hilos.
Libreria propia de Cuda
*/
__global__ void setup_kernel(curandState * state, unsigned long seed) {
	int id = threadIdx.x + blockIdx.x * blockDim.x;

	//cada thread tiene la misma semilla y un número distinto de secuencia
	curand_init(seed, id, 0, &state[id]);

}

/*Función que gneera un número aleatorio, comprendido entre 0 y el n-1 filas o columas que tenga*/
__global__ void generate(curandState* globalState, int *result, int nf) {
	int posx = threadIdx.x + blockIdx.x * blockDim.x;

	int max = nf;

	// copiar estado a la memoria local para mayor eficiencia
	curandState localState = globalState[posx];

	// generar número pseudoaleatorio
	int rx = curand(&localState) % max + 0;

	//copiar state de regreso a memoria global
	globalState[posx] = localState;

	//almacenar resultados
	result[posx] = rx;

}


int main()
{
	char *tablero_h; //tablero de juego en el host 
	char *tablero_d; //tablero de juego en el device
	int nf; //numero de filas
	int nc; //numro de  columnas
	int N;  //numero de elementos de la matriz (nc*nf)
	int BLOCK_SIZE = 4;
	bool casilla = false ; //variable que dirá si se llena o no la casilla 
	char modo; //modo de ejecución, automático o manual 
	int *vposx; //vector que almacena posicion x 
	int *vposy; //vector que almacena las posiciones y 
	curandState* devStates; //alamcena estados en el device 
	int *devResults; //vector donde se copian los puntos en el device
	int **vposiciones; //array bidimensional, para crear los puntos del tablero. 
	int nivel; //Nivel de juego, 8 o 15 semillas.
	
	//pedimos los datos por teclado
	printf("Introduzca el número de filas del tablero \n") ;
	scanf("%d", &nf);

	printf("Introduzca el número de columnas del tablero \n ");
	scanf("%d", &nc);

	//printf("¿Qué modo de funcionamiento quiere ? [ A | M ] \n");
	//scanf("%c", &modo);

	printf("Nivel de dificultad ( 8 | 15 )\n ");
	scanf("%d", &nivel);
	N = nf*nc;
	size_t size = N * sizeof(char);
	//Guardamos memoria eb las matrices con el tamaño de m*n*int
	tablero_h = (char*)malloc(size);

	//Inicializamos el tablero 
	for (int i = 0; i < nf; i++) {
		for (int j = 0; j < nc; j++) {
			
			tablero_h[i*nc + j] = '0';
		
		}
	}
	//incializamos los vectores de posiciones
	vposx = (int*)malloc(nf * sizeof(int));
	vposy = (int*)malloc(nf * sizeof(int));
	vposiciones = (int**)malloc(nivel * sizeof(int));


	//Asociamos memoria en el device
	cudaMalloc((void **)&tablero_d, size);

	//transferencia de datos 
	cudaMemcpy(tablero_d, tablero_h, size, cudaMemcpyHostToDevice);
	
	//realizamos la multiplicacion en el device
	dim3 block_size(BLOCK_SIZE, BLOCK_SIZE);
	dim3 n_blocks(N / BLOCK_SIZE, N / BLOCK_SIZE);

	//Tranaferimos el resultado del Device al Host
	cudaMemcpy(tablero_h, tablero_d, size, cudaMemcpyDeviceToHost);

	//reserva de memoria dinámica
	for (int i = 0; i< nivel; i++)
		vposiciones[i] = (int *)malloc(2 * sizeof(int));

	for (int i = 0; i < nivel; i++) {
		for (int j = 0; j < 2; j++) {
			vposiciones[i][1] = 0;
		}
	}
	// reservando espacio para los states PRNG en el device
	cudaMalloc(&devStates, nivel * sizeof(curandState));

	// reservando espacio para el vector de resultados en device
	cudaMalloc((void**)&devResults, nivel * sizeof(int));
	dim3 tpb(nf, 1, 1);

	// setup semillas
	setup_kernel << <1, tpb >> >(devStates, time(0));

	// generar números aleatorios para coordenadas x
	generate << <1, tpb >> >(devStates, devResults, nivel);

	//copiamos del device al host
	cudaMemcpy(vposx, devResults, nivel * sizeof(int),
		cudaMemcpyDeviceToHost);
	//liberamos memoria de las coordenadas x
	
	//generamos números aleatorios para coordenadas y 
	generate << <1, tpb >> >(devStates, devResults, nivel);

	cudaMemcpy(vposy, devResults, nivel * sizeof(int),
		cudaMemcpyDeviceToHost);

	cudaFree(devStates);
	cudaFree(devResults);


	for (int i = 0; i < nivel; i++) {
		vposiciones[i][0] = vposx[i];
		vposiciones[i][1] = vposy[i];
	}

	for (int i = 0; i < nivel; i++) {
		printf("\n ");
		for (int j = 0; j < 2; j++) {
			printf("  %d  ", vposiciones[i][j]);
		}

	}
	


	//Resultado
	printf("El resultado de la matriz es \n");
	for (int i = 0; i < nf; i++) {
		for (int j = 0; j < nc; j++) {
			printf("  %c  ", tablero_h[i*nc + j]);
		}
		printf("\n");
	}

	getchar(); //se cierra la ventana si no pongo esto. 
	getchar();
	free(tablero_h);
	cudaFree(tablero_d);
	
	return(0);

}

