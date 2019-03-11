
#include "cuda.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdlib.h> 
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <time.h>
#include <stdio.h>
#include <ctime>
#include <cstdlib>
#include <string>
#include <sstream>
#include <vector>
#include <curand_kernel.h>

#include "common/book.h"

#include <conio.h>
#define KEY_UP 72
#define KEY_DOWN 80
#define KEY_LEFT 75
#define KEY_RIGHT 77
#define LIVES 5

__global__ void flip (float *tablero, int mitad_low, int mitad_up) {
	int id = threadIdx.x;
	int look = mitad_low + mitad_up - id - 1;
	float value = tablero[look];
	__syncthreads();
	tablero[id] = value;
}

__global__ void moverDeDerechaAIzquierda(float *tablero, int nc) {
	int id = threadIdx.x * nc;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nc; ++e) {
		i = id + e;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion + 1;
				if (i != ultima_ficha_posicion) {
					tablero[i] = 0;
				}
			}
			else {
				if (hay_hueco) {
					tablero[ultimo_hueco] = tablero[i];
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = ultimo_hueco;
					hay_hueco = (ultimo_hueco <= i);
					if (i != ultimo_hueco) {
						tablero[i] = 0;
					}
					++ultimo_hueco;
				}
				else {
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = i;
					ultimo_hueco = i;
					hay_hueco = false;
				}
			}
		}
		else {
			if (!hay_hueco) {
				hay_hueco = true;
				ultimo_hueco = i;
			}
		}
	}
}

__global__ void moverDeIzquierdaADerecha(float *tablero, int nc) {
	int id = threadIdx.x * nc + nc - 1;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nc; ++e) {
		i = id - e;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion - 1;
				if (i != ultima_ficha_posicion) {
					tablero[i] = 0;
				}
			}
			else {
				if (hay_hueco) {
					tablero[ultimo_hueco] = tablero[i];
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = ultimo_hueco;
					hay_hueco = (ultimo_hueco >= i);
					if (i != ultimo_hueco) {
						tablero[i] = 0;
					}
					--ultimo_hueco;
				}
				else {
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = i;
					ultimo_hueco = i;
					hay_hueco = false;
				}
			}
		}
		else {
			if (!hay_hueco) {
				hay_hueco = true;
				ultimo_hueco = i;
			}
		}
	}
}

__global__ void moverDeAbajoAArriba(float *tablero, int nc, int nf) {
	int id = threadIdx.x;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nf; ++e) {
		i = id + nc * e;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion + nc;
				if (i != ultima_ficha_posicion) {
					tablero[i] = 0;
				}
			}
			else {
				if (hay_hueco) {
					tablero[ultimo_hueco] = tablero[i];
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = ultimo_hueco;
					hay_hueco = (ultimo_hueco <= i);
					if (i != ultimo_hueco) {
						tablero[i] = 0;
					}
					ultimo_hueco += nc;
				}
				else {
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = i;
					ultimo_hueco = i;
					hay_hueco = false;
				}
			}
		}
		else {
			if (!hay_hueco) {
				hay_hueco = true;
				ultimo_hueco = i;
			}
		}
	}
}

__global__ void moverDeArribaAAbajo(float *tablero, int nc, int nf) {
	int id = nf * nc - threadIdx.x;
	int i;
	bool hay_hueco = (tablero[id] == 0);
	int ultimo_hueco = id;
	float ultima_ficha = hay_hueco ? 0 : tablero[id];
	int ultima_ficha_posicion = id;
	for (int e = 1; e < nf; ++e) {
		i = id - e * nc;
		if (tablero[i] != 0) {
			if (tablero[i] == ultima_ficha) {
				tablero[ultima_ficha_posicion] = ultima_ficha * 2;
				ultima_ficha = 0;
				hay_hueco = true;
				ultimo_hueco = ultima_ficha_posicion - nc;
				if (i != ultima_ficha_posicion) {
					tablero[i] = 0;
				}
			}
			else {
				if (hay_hueco) {
					tablero[ultimo_hueco] = tablero[i];
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = ultimo_hueco;
					hay_hueco = (ultimo_hueco >= i);
					if (i != ultimo_hueco) {
						tablero[i] = 0;
					}
					ultimo_hueco -= nc;
				}
				else {
					ultima_ficha = tablero[i];
					ultima_ficha_posicion = i;
					ultimo_hueco = i;
					hay_hueco = false;
				}
			}
		}
		else {
			if (!hay_hueco) {
				hay_hueco = true;
				ultimo_hueco = i;
			}
		}
	}
}

__global__ void takeDecisions(float *tablero, float *decisions, int nc, int nf) {
	int id = threadIdx.x;
	int index = id;
	int colum_index = id % nc;
	float value = tablero[id];
	bool perform_movement = false;
	bool different_value_found = false;
	while ((colum_index > 0) && !different_value_found) {
		--index;
		--colum_index;
		float new_value = tablero[index];
		if (new_value == value) {
			perform_movement = !perform_movement;
		}
		if ((new_value != 0) && (new_value != value)) {
			different_value_found = true;
		}
	}
	if (perform_movement) {
		decisions[id] = value * 2;
	}
}

__global__ void  sumLeft(float* tablero, float* result, int nc, int nf) {
	int id = threadIdx.x;
	int colum = id % nc;
	int row = id / nc;
	result[id] = 0;
	if (tablero[id]) {
		if (((colum + 1) < nc) && (tablero[id] == tablero[id + 1 ])) {
			result[id] = 1;
			//printf("1 id: %d colum: %d, row: %d\n", id, colum, row);
		}
		if (((colum - 1) > 0) && (tablero[id] == tablero[id - 1])) {
			result[id] = 1;
			//printf("2 id: %d colum: %d, row: %d\n", id, colum, row);
		}
		if (((row + 1) < nf) && (tablero[id] == tablero[id + nc])) {
			result[id] = 1;
			//printf("3 id: %d colum: %d, row: %d\n", id, colum, row);
		}
		if (((row - 1) > 0) && (tablero[id] == tablero[id - nc])) {
			result[id] = 1;
			//printf("4 id: %d colum: %d, row: %d\n", id, colum, row);
		}
	}
}

__global__ void sumPoints(float *decisions, float *sum_result, int max_elements, int max_steps) {
	int id = threadIdx.x;
	sum_result[id] = decisions[id];
	__syncthreads();
	for (int step = 1; step < max_steps+1; ++step) {
		int active_thread = powf(2, step);
		int pair_id = powf(2, step - 1);
		if (((id % active_thread) == 0) && ((id + pair_id) < max_elements)) {
			float suma = sum_result[id] + sum_result[id + pair_id];
			sum_result[id] = suma;
		} 
		__syncthreads();
	}
}

__global__ void sumGaps(float *decisions, float *sum_result, int max_elements, int max_steps) {
	int id = threadIdx.x;
	sum_result[id] = (float)(decisions[id] == 0.0f);
	__syncthreads();
	for (int step = 1; step < max_steps + 1; ++step) {
		int active_thread = powf(2, step);
		int pair_id = powf(2, step - 1);
		if (((id % active_thread) == 0) && ((id + pair_id) < max_elements)) {
			float suma = sum_result[id] + sum_result[id + pair_id];
			sum_result[id] = suma;
		}
		__syncthreads();
	}
}

__global__ void sumMovements(float *decisions, float *sum_result, int max_elements, int max_steps) {
	int id = threadIdx.x;
	sum_result[id] = (float)(decisions[id] != 0.0f);
	__syncthreads();
	for (int step = 1; step < max_steps + 1; ++step) {
		int active_thread = powf(2, step);
		int pair_id = powf(2, step - 1);
		if (((id % active_thread) == 0) && ((id + pair_id) < max_elements)) {
			float suma = sum_result[id] + sum_result[id + pair_id];
			sum_result[id] = suma;
		}
		__syncthreads();
	}
}

__host__ void check_CUDA_Error(const char *mensaje) {
	cudaError_t error;
	cudaDeviceSynchronize();
	error = cudaGetLastError();
	if (error != cudaSuccess) {
		printf("ERROR %d: %s (%s)\n", error, cudaGetErrorString(error), mensaje); printf("\npulsa INTRO para finalizar...");
		fflush(stdin);
		char tecla = getchar();
		exit(-1);
	}
}


template <class T>
__host__ std::string printTablero(T *tablero, int n_filas, int n_columnas) {
	std::stringstream ss;
	for (int i = 0; i < n_filas; i++) {
		for (int j = 0; j < n_columnas; j++) {
			ss << tablero[i*n_columnas + j] << ", ";
		}
		ss << "\n";
	}
	return ss.str();
}

/*Pone la cantidad de números aleatorios indicada en el tablero siempre que se pueda*/
template <class T>
__host__ void addRandom (T *tablero, int elements, int len) {
	std::vector<int> available_positions;
	available_positions.reserve(len);
	for (int i = 0; i < len; ++i) {
		if (tablero[i] == 0) {
			available_positions.emplace_back(i);
		}
	}
	if (available_positions.size() <= 0) return;
	int takes = static_cast<int>((elements < available_positions.size())? elements : available_positions.size());
	do {
		int random = static_cast<int>(std::rand() % available_positions.size());
		tablero[available_positions[random]] = (static_cast<T>(std::rand() % 2) + 1) * ((takes > 8) ? 4 : 2);
		available_positions.erase(available_positions.begin() + random, available_positions.begin() + random + 1);
		--takes;
	} while (takes > 0);
}

__host__ std::string replicateString(std::string str, int amount) {
	std::stringstream ss;
	for (int i = 0; i < amount*3; ++i) {
		ss << str;
	}
	return ss.str();
}

template <class T>
__host__ T sumArray(T *arr, int len) {
	T sum = 0;
	for (int i = 0; i < len; ++i) {
		sum += arr[i];
	}
	return sum;
}

int main(int argc, char **argv) {
	std::srand(static_cast<int>(time(0)));
	float *tablero_h;
	float *tablero_d;
	float *decisions_h;
	float *decisions_d;
	float *sum_points_h;
	float *sum_points_d;
	float *sum_gaps_h;
	float *sum_gaps_d;
	float *movements_left_h;
	float *movements_left_d;
	float *movements_left_aux_h;
	float *movements_left_aux_d;
	float *movements_performed_h;
	float *movements_performed_d;
	int n_filas;
	int n_columnas;
	int n_elementos; 
	size_t size_elementos;
	int elementos_iniciales;
	char modo_ejecucion;

	cudaDeviceProp prop;
	HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
	std::cout << std::endl;
	std::cout << "Multiprocesor count: " << prop.multiProcessorCount << std::endl;
	std::cout << "Max Threads per multiprocesor: " << prop.maxThreadsPerMultiProcessor << std::endl;
	std::cout << "Max Threads per block: " << prop.maxThreadsPerBlock << std::endl << std::endl;

	if (argc < 4) {
		std::cout << "Modo de ejecucion [ a | m ]: ";
		std::cin >> modo_ejecucion;
		std::cout << "Cuantos elementos iniciales quiere [ 1 = 8 | 2 = 15 ]: ";
		std::cin >> elementos_iniciales;
		std::cout << "Introduzca el numero de filas del tablero: ";
		std::cin >> n_filas;
		std::cout << "Introduzca el numero de columnas del tablero: ";
		std::cin >> n_columnas;
	} else {
		n_filas = std::atoi(argv[3]);
		n_columnas = std::atoi(argv[2]);
		modo_ejecucion = static_cast<char>(std::atoi(argv[1]));
		elementos_iniciales = std::atoi(argv[0]);
	}
	if (n_filas < 4) {
		std::cout << "Filas insuficientes" << std::endl;
		n_filas = 4;
	}
	if (n_columnas < 4) {
		std::cout << "Columnas insuficientes" << std::endl;
		n_columnas = 4;
	}
	if ((modo_ejecucion != 'a') && (modo_ejecucion != 'm')) {
		std::cout << "Modo de ejecución incorrecto, por defecto manual" << std::endl;
		modo_ejecucion = 'm';
	}
	if (elementos_iniciales < 0) {
		std::cout << "Elementos iniciales insuficientes" << std::endl;
		elementos_iniciales = 15;
	}
	switch (elementos_iniciales) {
	case 0: {
		elementos_iniciales = 2;
	} break;
	case 1: {
		elementos_iniciales = 8;
	} break;
	case 2: {
		elementos_iniciales = 15; 
	} break;
	}
	n_elementos = n_filas * n_columnas;
	size_elementos = sizeof(float) * n_elementos;
	int max_recursion = static_cast<int>(std::ceil(std::log2(n_elementos)));

	std::cout << std::endl;
	std::cout << "Columnas : " << n_columnas << " | Filas: " << n_filas << " -> Elementos: " << n_elementos << " | Max recursion: " << max_recursion << std::endl;
	std::cout << "Modo: " << ((modo_ejecucion == 'a') ? "automatico" : "manual") << " | Elementos iniciales: " << elementos_iniciales << std::endl << std::endl;

	tablero_h = (float*)malloc(size_elementos);
	decisions_h = (float*)malloc(size_elementos);
	sum_points_h = (float*)malloc(size_elementos);
	sum_gaps_h = (float*)malloc(size_elementos); 
	movements_left_h = (float*)malloc(size_elementos);
	movements_left_aux_h = (float*)malloc(size_elementos);
	movements_performed_h = (float*)malloc(size_elementos);
	HANDLE_ERROR(cudaMalloc((void **)&tablero_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&decisions_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&sum_points_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&sum_gaps_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_left_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_left_aux_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_performed_d, size_elementos));
	memset(tablero_h, 0, size_elementos);
	memset(decisions_h, 0, size_elementos);
	memset(sum_points_h, 0, size_elementos);
	memset(sum_gaps_h, 0, size_elementos);
	memset(movements_left_h, 0, size_elementos);
	memset(movements_left_aux_h, 0, size_elementos);
	memset(movements_performed_h, 0, size_elementos);
	addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
	int round = 0;
	int lives = LIVES;
	int score [LIVES];
	memset(score, 0, sizeof(int)*LIVES);
	std::string sidebar = replicateString ("-", static_cast<int>(n_columnas*2));
	std::string spaces = replicateString (" ", n_columnas);
	char movement_to_perform = -1;
	bool move_done = true;
	do {
		if (move_done) {
			std::cout << sidebar << std::endl;
			std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
			std::cout << "Score: " << score[lives-1] << std::endl;
			std::cout << sidebar << std::endl;
			std::cout << printTablero(tablero_h, n_filas, n_columnas) << std::endl;
		}
		move_done = false;
		if (modo_ejecucion == 'm') {
			movement_to_perform = getch();
		} else {
			getch();
			movement_to_perform = 0;
		}
		if (movement_to_perform == 0 || static_cast<int>(movement_to_perform) == -32) {	
			//SUBIR A DEVICE
			HANDLE_ERROR(cudaMemcpy(tablero_d, tablero_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(decisions_d, decisions_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(sum_points_d, sum_points_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(sum_gaps_d, sum_gaps_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(movements_left_d, movements_left_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(movements_left_d, movements_left_aux_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(movements_performed_d, movements_performed_h, size_elementos, cudaMemcpyHostToDevice));
			//TOMAR DECISIONES
			takeDecisions << <1, n_elementos, 1 >> > (tablero_d, decisions_d, n_columnas, n_filas);
			check_CUDA_Error("DECISIONES");

			HANDLE_ERROR(cudaMemcpy(decisions_h, decisions_d, size_elementos, cudaMemcpyDeviceToHost));
			std::cout << sidebar << std::endl;
			std::cout << printTablero(decisions_h, n_filas, n_columnas) << std::endl;
			std::cout << sidebar << std::endl;

			//SUMAR PUNTOS
			sumPoints << <1, n_elementos, 1 >> > (decisions_d, sum_points_d, n_elementos, max_recursion);
			check_CUDA_Error("SUMA PUNTOS");
			HANDLE_ERROR(cudaMemcpy(sum_points_h, sum_points_d, size_elementos, cudaMemcpyDeviceToHost));
			score[lives - 1] += static_cast<int>(sum_points_h[0]);

			//SUMA HUECOS
			sumGaps << <1, n_elementos, 1 >> > (tablero_d, sum_gaps_d, n_elementos, max_recursion);
			check_CUDA_Error("SUMA HUECOS");
			HANDLE_ERROR(cudaMemcpy(sum_gaps_h, sum_gaps_d, size_elementos, cudaMemcpyDeviceToHost));
			std::cout << sum_gaps_h[0] << std::endl;

			//SUMAR MOVIMIENTOS
			sumMovements << <1, n_elementos, 1 >> > (decisions_d, movements_performed_d, n_elementos, max_recursion);
			check_CUDA_Error("SUMA MOVIMIENTOS");
			HANDLE_ERROR(cudaMemcpy(movements_performed_h, movements_performed_d, size_elementos, cudaMemcpyDeviceToHost));
			std::cout << movements_performed_h[0] << std::endl;
			if (modo_ejecucion == 'm') {
				movement_to_perform = getch();
			} else {//IA
				int action = static_cast<int>(std::rand() % 100);
				if (action < 35) {
					movement_to_perform = KEY_RIGHT;
					std::cout << "RIGHT" << std::endl;
				} else if (action < 70) {
					movement_to_perform = KEY_LEFT;
					std::cout << "LEFT" << std::endl;
				} else if (action < 95) {
					movement_to_perform = KEY_DOWN;
					std::cout << "DOWN" << std::endl;
				} else {
					movement_to_perform = KEY_UP;
					std::cout << "UP" << std::endl;
				}
			}
			//MOVER CON LAS DECISIONES TOMADAS
			switch (movement_to_perform) {
			case KEY_UP:
				
				break;
			case KEY_LEFT:

				break;
			case KEY_DOWN:

				break;
			case KEY_RIGHT:

				break;
			}
			check_CUDA_Error("MOVER");
			//COMPROBAR SI IGUAL QUE LA ENTERIOR
			//EN ESE CASO NO SUMAR LOS PUNTOS

			HANDLE_ERROR(cudaMemcpy(tablero_h, tablero_d, size_elementos, cudaMemcpyDeviceToHost));
			addRandom<float>(tablero_h, (static_cast<int>(std::rand() % 2) + 1), n_elementos);
			HANDLE_ERROR(cudaMemcpy(tablero_d, tablero_h, size_elementos, cudaMemcpyHostToDevice));

			//QUEDAN MOVIMIENTOS?
			sumLeft << <1, n_elementos, 1 >> > (tablero_d, movements_left_aux_d, n_columnas, n_filas);
			check_CUDA_Error("MOVEMENTS LEFT AUX");
			sumMovements << <1, n_elementos, 1 >> > (movements_left_aux_d, movements_left_d, n_elementos, max_recursion);
			check_CUDA_Error("MOVEMENTS LEFT SUM");
			HANDLE_ERROR(cudaMemcpy(movements_left_h, movements_left_d, size_elementos, cudaMemcpyDeviceToHost));
			std::cout << movements_left_h[0] << std::endl;

			if ((sum_gaps_h[0] < 0) && (movements_left_h[0] <= 0)) {
				--lives;
				std::cout << sidebar << std::endl;
				std::cout << "Lives:" << lives << std::endl;
				std::cout << "TotalScore: " << sumArray(score, LIVES) << std::endl;
				std::cout << sidebar << std::endl;
				memset(decisions_h, 0, size_elementos);
			}
			else {
				++round;
				move_done = true;
			}
			memset(decisions_h, 0, size_elementos);
			memset(sum_points_h, 0, size_elementos);
			memset(sum_gaps_h, 0, size_elementos);
			memset(movements_left_h, 0, size_elementos);
			memset(movements_left_aux_h, 0, size_elementos);
			memset(movements_performed_h, 0, size_elementos);
		}
		if (movement_to_perform == 'm') {
			std::cout << "Escriba el nuevo modo [ a | m ]: ";
			std::cin >> modo_ejecucion;
			if ((modo_ejecucion != 'a') && (modo_ejecucion != 'm')) {
				std::cout << "Modo de ejecución incorrecto, por defecto manual" << std::endl;
				modo_ejecucion = 'm';
			}
		}
		else if (movement_to_perform == 'g') {
			std::string file_name;
			std::cout << "Escriba el nombre con el que guardar su partida: ";
			std::cin >> file_name;
			std::ofstream file;
			file.open(file_name, std::ios::out | std::ios::trunc | std::ios::binary);
			file << n_columnas << " " << n_filas << " " << lives << " " << round << " ";
			for (int i = 0; i < LIVES; ++i) {
				file << score[i] << " ";
			}
			for (int i = 0; i < n_elementos; ++i) {
				file << tablero_h[i] << " ";
			}
			file.close();
			std::cout << "Matriz guardada, puede seguir jugando" << std::endl;
		} else if (movement_to_perform == 'c') {
			std::string file_name;
			std::cout << "Escriba el nombre de su partida a cargar: ";
			std::cin >> file_name;
			std::ifstream file (file_name, std::ios::in | std::ios::binary);
			if (file.is_open()) {
				std::string line; 
				std::getline(file, line);
				std::istringstream in(line);
				in >> n_columnas;
				in >> n_filas;
				in >> lives;
				in >> round;
				for (int i = 0; i < LIVES; ++i) {
					in >> score[i];
				}

				n_elementos = n_filas * n_columnas;
				size_elementos = sizeof(float) * n_elementos;
				max_recursion = static_cast<int>(std::ceil(std::log2(n_elementos)));

				tablero_h = (float*)malloc(size_elementos);
				decisions_h = (float*)malloc(size_elementos);
				sum_points_h = (float*)malloc(size_elementos);
				sum_gaps_h = (float*)malloc(size_elementos);
				movements_left_h = (float*)malloc(size_elementos);
				movements_left_aux_h = (float*)malloc(size_elementos);
				movements_performed_h = (float*)malloc(size_elementos);
				HANDLE_ERROR(cudaMalloc((void **)&tablero_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&decisions_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&sum_points_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&sum_gaps_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_left_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_left_aux_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_performed_d, size_elementos));
				memset(tablero_h, 0, size_elementos);
				memset(decisions_h, 0, size_elementos);
				memset(sum_points_h, 0, size_elementos);
				memset(sum_gaps_h, 0, size_elementos);
				memset(movements_left_h, 0, size_elementos);
				memset(movements_left_aux_h, 0, size_elementos);
				memset(movements_performed_h, 0, size_elementos);
				sidebar = replicateString("-", static_cast<int>(n_columnas * 2));
				spaces = replicateString(" ", n_columnas);

				for (int i = 0; i < n_elementos; ++i) {
					in >> tablero_h[i];
				}
				
				std::cout << std::endl;
				std::cout << sidebar << std::endl;
				std::cout << "Columnas : " << n_columnas << " | Filas: " << n_filas << " -> Elementos: " << n_elementos << " | Max recursion: " << max_recursion << std::endl;
				std::cout << sidebar << std::endl;
				std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
				std::cout << "Score: " << score[lives - 1] << std::endl;
				std::cout << sidebar << std::endl;
				std::cout << printTablero(tablero_h, n_filas, n_columnas) << std::endl;
				std::cout << sidebar << std::endl;
				std::cout << "Matriz cargada, puede seguir jugando" << std::endl;
				std::cout << sidebar << std::endl;
			} else {
				std::cout << "El archivo de carga no existe!!!" << std::endl << std::endl;
			}
			file.close();
		}
	} while (movement_to_perform!='e' && (lives > 0));

	std::cout << sidebar << std::endl;
	std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << printTablero(tablero_h, n_filas, n_columnas) << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << "Game over!!!" << std::endl;
	std::cout << "TotalScore: " << sumArray<int>(score, LIVES) << std::endl;
	std::cout << sidebar << std::endl;

	free(tablero_h);
	free(decisions_h);
	free(sum_points_h);
	free(sum_gaps_h);
	free(movements_left_h);
	free(movements_left_aux_h);
	free(movements_performed_h);
	HANDLE_ERROR(cudaFree(tablero_d));
	HANDLE_ERROR(cudaFree(decisions_d));
	HANDLE_ERROR(cudaFree(sum_points_d));
	HANDLE_ERROR(cudaFree(sum_gaps_d));
	HANDLE_ERROR(cudaFree(movements_left_d));
	HANDLE_ERROR(cudaFree(movements_left_aux_d));
	HANDLE_ERROR(cudaFree(movements_performed_d));

	getchar(); //se cierra la ventana si no pongo esto. 
	return(0);
}

