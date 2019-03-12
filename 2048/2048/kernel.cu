
#include "cuda.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdlib.h> 
#include <stdio.h>
#include <iostream>
#include <iomanip>
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
#include "windows.h"
#define KEY_UP 72
#define KEY_DOWN 80
#define KEY_LEFT 75
#define KEY_RIGHT 77
#define LIVES 5
#define RANDOM_IA 1

/*
OUTPUT FORMATER
Convierte los datos a formato centrado en el hueco que se les ha reservado en el buffer de salida
Se utiliza para mostrar los número en el centro de su casilla.
*/
template<typename charT, typename traits = std::char_traits<charT> >
class center_helper {
	std::basic_string<charT, traits> str_;
public:
	center_helper(std::basic_string<charT, traits> str) : str_(str) {}
	template<typename a, typename b>
	friend std::basic_ostream<a, b>& operator<<(std::basic_ostream<a, b>& data, const center_helper<a, b>& center);
};
template<typename charT, typename traits = std::char_traits<charT> >
center_helper<charT, traits> centered(std::basic_string<charT, traits> str) {
	return center_helper<charT, traits>(str);
}
center_helper<std::string::value_type, std::string::traits_type> centered(const std::string& str) {
	return center_helper<std::string::value_type, std::string::traits_type>(str);
}
template<typename charT, typename traits>
std::basic_ostream<charT, traits>& operator<<(std::basic_ostream<charT, traits>& data, const center_helper<charT, traits>& center) {
	std::streamsize width = data.width();
	if (static_cast<long>(width) > static_cast<long>(center.str_.length())) {
		std::streamsize left = (width + center.str_.length()) / 2;
		data.width(left);
		data << center.str_;
		data.width(width - left);
		data << "";
	} else {
		data << center.str_;
	}
	return data;
}
/*
Convierte la matriz en su simétrica por el eje Vertical
La matriz es tanto de entrada como de salida
Se utiliza para hacer el movimiento horizonal a la derecha
*/
__global__ void flipH (float *tablero, int size, int nc) {
	int id = threadIdx.x;
	int colum = id % nc;
	int row = id / nc;
	int look = (nc - colum - 1) + row * nc;
	float value = 0;
	if (look < size) {
		value = tablero[look];
	}
	__syncthreads();
	if ((id < size) && (look < size)) {
		tablero[id] = value;
	}
}
/*
Convierte la matriz en su simétrica por el eje Horizontal
La matriz es tanto de entrada como de salida
Se utiliza para hacer el movimiento vertical hacia abajo
*/
__global__ void flipV(float *tablero, int size, int nc, int nf) {
	int id = threadIdx.x;
	int colum = id % nc;
	int row = id / nc;
	int look = colum + (nf - row - 1) * nc;
	float value = 0;
	if (look < size) {
		value = tablero[look];
	}
	__syncthreads();
	if ((id < size) && (look < size)) {
		tablero[id] = value;
	}
}

/*
Realiza los el movimiento horizontal (izquierda) en el tablero según la matriz de decisiones
La matriz tablero es de entrada y salida
La matriz de decisiones queda destruida cuando se realiza el movimiento
Las decisiones indican a los hilos como comportarse, es decir, si deben sumarse o no,
con ello se evita que cuatro números iguales seguidos se sumen en uno solo, quedarían en dos iguales contiguos o
se logra que cuando hay tres número iguales se respete el orden de su suma
*/
__global__ void moveH(float *tablero, float *decisions, int size, int nc) {
	int id = threadIdx.x;
	int colum = id % nc;
	bool tiene_izquierda = colum != 0; //Si el número NO tiene izquierda no debe hacer nada
	float izquierda = 0;
	float propio = 0;
	float decision = 0;
	for (int i = 0; i < (nc - 1); ++i) {//Iteraciones mínimar para garantizar completitud
		__syncthreads();//LECTURA DE DATOS
		if (tiene_izquierda) {
			if (id < size) {
				izquierda = tablero[id - 1];
				propio = tablero[id];
				decision = decisions[id];
			}
		}
		__syncthreads();//ACTUACIÓN
		if (tiene_izquierda) {
			if (decision == 0) {
				if ((izquierda == 0) && (propio!=0)) {
					if (id < size) {
						tablero[id - 1] = propio;
						tablero[id] = 0;
					}
				}
			} else {
				if (izquierda == 0) {
					if (id < size) {
						tablero[id - 1] = propio;
						decisions[id - 1] = decision;
						tablero[id] = 0;
					}
				}
				if (izquierda == propio) {
					if (id < size) {
						tablero[id - 1] = propio * 2;
						decisions[id] = 0;
						tablero[id] = 0;
					}
				}
			}
		}
	}
}

/*
Realiza los el movimiento verical (arriba) en el tablero según la matriz de decisiones
La matriz tablero es de entrada y salida
La matriz de decisiones queda destruida cuando se realiza el movimiento
Las decisiones indican a los hilos como comportarse, es decir, si deben sumarse o no,
con ello se evita que cuatro números iguales seguidos se sumen en uno solo, quedarían en dos iguales contiguos o
se logra que cuando hay tres número iguales se respete el orden de su suma
*/
__global__ void moveV(float *tablero, float *decisions, int size, int nc, int nf) {
	int id = threadIdx.x;
	int row = id / nc;
	bool tiene_arriba = row != 0; //Si el número NO tiene arriba no debe hacer nada
	float arriba = 0;
	float propio = 0;
	float decision = 0;
	for (int i = 0; i < (nf - 1); ++i) {//Iteraciones mínimar para garantizar completitud
		__syncthreads();//LECTURA DE DATOS
		if (tiene_arriba) {
			arriba = tablero[id - nc];
			propio = tablero[id];
			decision = decisions[id];
		}
		__syncthreads();//ACTUACIÓN
		if (tiene_arriba) {
			if (decision == 0) {
				if ((arriba == 0) && (propio != 0)) {
					if (id < size) {
						tablero[id - nc] = propio;
						tablero[id] = 0;
					}
				}
			} else {
				if (arriba == 0) {
					if (id < size) {
						tablero[id - nf] = propio;
						decisions[id - nf] = decision;
						tablero[id] = 0;
					}
				}
				if (arriba == propio) {
					if (id < size) {
						tablero[id - nf] = propio * 2;
						decisions[id] = 0;
						tablero[id] = 0;
					}
				}
			}
		}
	}
}

/*
Toma las decisiones para los movientos en horizontal (izquierda).
Deja el valor que se obtendrá tras añadir dos elementos en la posición del elemento que se va a añadir
Sirve también para saber los puntos que se obtiene al hacer el moviento y contar los movientos realizados
Se pondrá el valor a obtener en elementos que sumen con otro ocupan un lugar impar contando solo los ocupados...
...por elementos iguales desde el primero que no es igual a ellos
Tablero:    2222    400404
Decisiones: 0404    000800
*/
__global__ void takeDecisionsH(float *tablero, float *decisions,int size, int nc) {
	int id = threadIdx.x;
	int index = id;
	int colum_index = id % nc;
	float value = 0;
	float new_value = 0;
	bool perform_movement = false;
	bool different_value_found = false;
	if (id < size) {
		value = tablero[id];
	}
	while ((colum_index > 0) && !different_value_found) {
		--index;
		--colum_index;
		if (id < size) {
			new_value = tablero[index];
		}
		if (new_value == value) {
			perform_movement = !perform_movement;
		}
		if ((new_value != 0) && (new_value != value)) {
			different_value_found = true;
		}
	}
	if (perform_movement) {
		if (id < size) {
			decisions[id] = value * 2;
		}
	}
}

/*
Toma las decisiones para los movientos en vertical (arriba).
Deja el valor que se obtendrá tras añadir dos elementos en la posición del elemento que se va a añadir
Sirve también para saber los puntos que se obtiene al hacer el moviento y contar los movientos realizados
Se pondrá el valor a obtener en elementos que sumen con otro ocupan un lugar impar contando solo los ocupados...
...por elementos iguales desde el primero que no es igual a ellos
Tablero:    2222    400404
Decisiones: 0404    000800
*/
__global__ void takeDecisionsV(float *tablero, float *decisions,int size, int nc) {
	int id = threadIdx.x;
	int index = id;
	int row_index = id / nc;
	float value = 0;
	float new_value = 0;
	bool perform_movement = false;
	bool different_value_found = false;
	if (id < size) {
		value = tablero[id];
	}
	while ((row_index > 0) && !different_value_found) {
		index -= nc;
		--row_index;
		if (id < size) {
			new_value = tablero[index];
		}
		if (new_value == value) {
			perform_movement = !perform_movement;
		}
		if ((new_value != 0) && (new_value != value)) {
			different_value_found = true;
		}
	}
	if (perform_movement) {
		if (id < size) {
			decisions[id] = value * 2;
		}
	}
}

/*
Genera una matriz con un 1 en cada posición en la que se pueda hacer un moviento
Sumando el resultado de todos los unos sabremos si se pueden hacer movientos o no
Cada hilo mira a sus cuatro elementos de los lados y al suyo
*/
__global__ void  sumLeft(float* tablero, float* result,int size, int nc, int nf) {
	int id = threadIdx.x;
	int colum = id % nc;
	int row = id / nc;
	if (id < size) {
		result[id] = 0;
		if (tablero[id]) {
			if (((colum + 1) < nc) && (tablero[id] == tablero[id + 1])) {
				result[id] = 1;
			}
			if (((colum - 1) > 0) && (tablero[id] == tablero[id - 1])) {
				result[id] = 1;
			}
			if (((row + 1) < nf) && (tablero[id] == tablero[id + nc])) {
				result[id] = 1;
			}
			if (((row - 1) > 0) && (tablero[id] == tablero[id - nc])) {
				result[id] = 1;
			}
		}
	}
}

/*
Suma todos los valores de una matriz sin destruir la entrada
Utiliza el método de reducción binaria
Utilizada para contar los puntos que se ganan con un mviento
*/
__global__ void sumPoints(float *decisions, float *sum_result, int size, int max_steps) {
	int id = threadIdx.x;
	if (id < size) {
		sum_result[id] = decisions[id];
	}
	__syncthreads();
	for (int step = 1; step < max_steps+1; ++step) {
		int active_thread = powf(2, step);
		int pair_id = powf(2, step - 1);
		if (((id % active_thread) == 0) && ((id + pair_id) < size)) {
			if (id < size) {
				float suma = sum_result[id] + sum_result[id + pair_id];
				sum_result[id] = suma;
			}
		} 
		__syncthreads();
	}
}

/*
Cuenta los elementos idénticos a 0 en una matriz
Se utiliza para saber cuantos huecos quedan en el tablero
*/
__global__ void sumGaps(float *decisions, float *sum_result, int size, int max_steps) {
	int id = threadIdx.x;
	if (id < size) {
		sum_result[id] = (float)(decisions[id] == 0.0f);
	}
	__syncthreads();
	for (int step = 1; step < max_steps + 1; ++step) {
		int active_thread = powf(2, step);
		int pair_id = powf(2, step - 1);
		if (((id % active_thread) == 0) && ((id + pair_id) < size)) {
			if (id < size) {
				float suma = sum_result[id] + sum_result[id + pair_id];
				sum_result[id] = suma;
			}
		}
		__syncthreads();
	}
}

/*
Cuenta la cantidad de elementos distintos de 0 que hay en una matriz
Se utiliza para saber si un moviento realiza cambios sobre el tablero
*/
__global__ void sumMovements(float *decisions, float *sum_result, int size, int max_steps) {
	int id = threadIdx.x;
	if (id < size) {
		sum_result[id] = (float)(decisions[id] != 0.0f);
	}
	__syncthreads();
	for (int step = 1; step < max_steps + 1; ++step) {
		int active_thread = powf(2, step);
		int pair_id = powf(2, step - 1);
		if (((id % active_thread) == 0) && ((id + pair_id) < size)) {
			if (id < size) {
				float suma = sum_result[id] + sum_result[id + pair_id];
				sum_result[id] = suma;
			}
		}
		__syncthreads();
	}
}

__global__ void cpyMatrix(float *matriz, float *copia, int size) {
	int id = threadIdx.x;
	if (id < size) {
		copia[id] = matriz[id];
	}
}

/*
Comprueba si ha habido un error en la GPU
Se utiliza después de cada llamada a un kernell
*/
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

/*
Muestra el tablero por pantalla
*/
template <class T>
__host__ std::string printTablero(T *tablero, int n_columnas, int n_filas) {
	std::stringstream ss;
	HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
	for (int i = 0; i < n_filas; i++) {
		if (i == 0) {
			ss << "\xC9" << replicateString(replicateString("\xCD",5) + "\xCB", n_columnas-1) << replicateString("\xCD", 5) << "\xBB" << "\n";
		}
		ss << "\xBA";
		for (int j = 0; j < n_columnas; j++) {
			int num = static_cast<int>(tablero[i*n_columnas + j]);
			ss << std::setw(5) << centered(num==0?"":std::to_string(num)) << "\xBA";
		}
		ss << "\n";
		if (i == n_filas - 1) {
			ss << "\xC8" << replicateString(replicateString("\xCD", 5) + "\xCA", n_columnas - 1) << replicateString("\xCD", 5) << "\xBC";
		} else {
			ss << "\xBA" << replicateString(replicateString("\xCD", 5) + "\xCE", n_columnas - 1) << replicateString("\xCD", 5) << "\xBA";
		}
		ss << "\n";
	}
	return ss.str();
}

/*
Pone la cantidad de números aleatorios indicada en el tablero siempre que se pueda
*/
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

/*
Da un string con el string proporcionado repetido tantas veces como se indique
*/
__host__ std::string replicateString(std::string str, int amount) {
	std::stringstream ss;
	for (int i = 0; i < amount; ++i) {
		ss << str;
	}
	return ss.str();
}

/*
Suma un array en la CPU
Se utiliza SOLO para sumar los puntos del array de 5 elementos de la puntuación conseguida con cada vida
*/
template <class T>
__host__ T sumArray(T *arr, int len) {
	T sum = 0;
	for (int i = 0; i < len; ++i) {
		sum += arr[i];
	}
	return sum;
}

int main(int argc, char **argv) {
	CONSOLE_FONT_INFOEX font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {8,14},FF_DONTCARE,FW_NORMAL};
	SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE) ,true,&font); //Control de la fuente
	ShowWindow(GetConsoleWindow(), SW_MAXIMIZE);//Consola en pantalla completa
	std::srand(static_cast<int>(time(0)));
	float *tablero_h;//Almacena la posicion de las fichas
	float *tablero_d;
	float *decisions_h;//Almacena las decisiones que permiten tomar los movimientos
	float *decisions_d;
	//Metricas de juego
	float *sum_points_h;//Para realizar la suma de los puntos
	float *sum_points_d;
	float *sum_gaps_h;//Evalúa lo bueno o malo que es el movimiento
	float *sum_gaps_d;
	float *movements_left_h;//Indica los movimiento que se pueden hacer
	float *movements_left_d;
	float *movements_left_aux_h;//El calculo de los movientos que quedan por hacer se hace en dos fases, con esta matriz auxiliar se...
	float *movements_left_aux_d;//...evita perder los datos de la primera fase 
	float *movements_performed_h;//Da la cantidad de movimentos realizada
	float *movements_performed_d;
	float *decisions_cpy_h;//Copia de las decisiones pues se pierden al realizar el moviento
	float *decisions_cpy_d;
	float *ia_tablero_h;
	float *ia_tablero_d;
	float *ia_decisions_h;
	float *ia_decisions_d;
	//Datos de tablero
	int n_filas;
	int n_columnas;
	int n_elementos; 
	size_t size_elementos;
	int elementos_iniciales;
	char modo_ejecucion;
	int max_recursion;//Profundidad de los algoritmos de reducción binaria
	//Datos de la UI
	int round = 0;
	int score[LIVES];
	int lives = LIVES;
	char movement_to_perform = -1;//Movimiento elegido por la IA o el jugador
	bool move_done = true;//Indica si el movimiento produjo cambios
	//Forman parte de la UI
	std::string sidebar;
	std::string spaces;
	//Características de la tarjeta
	cudaDeviceProp prop;
	HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
	std::cout << std::endl;
	std::cout << "Multiprocesor count: " << prop.multiProcessorCount << std::endl;
	std::cout << "Max Threads per multiprocesor: " << prop.maxThreadsPerMultiProcessor << std::endl;
	std::cout << "Max Threads per block: " << prop.maxThreadsPerBlock << std::endl << std::endl;
	//Se cargan los datos de inicio de partida
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
	//Comprobación de datos de incio de partida
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
	case 0: {//Para poder jugar al modo tradicional con solo un elemento incial 4x4
		elementos_iniciales = 1;
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
	max_recursion = static_cast<int>(std::ceil(std::log2(n_elementos)));
	sidebar = replicateString("\xC4", static_cast<int>(n_columnas) * 6 + 1);
	spaces = replicateString(" ", n_columnas);
	//Datos de inicio de nueva partida
	std::cout << std::endl;
	std::cout << "Columnas : " << n_columnas << " | Filas: " << n_filas << " -> Elementos: " << n_elementos << " | Max recursion: " << max_recursion << std::endl;
	std::cout << "Modo: " << ((modo_ejecucion == 'a') ? "automatico" : "manual") << " | Elementos iniciales: " << elementos_iniciales << std::endl << std::endl;
	if (n_elementos > prop.maxThreadsPerBlock) {
		std::cout << "La matriz es demasiado grande!!!" << std::endl;
		std::cout << "Press any key to continue" << std::endl;
		getch();
		exit(-1);
	}
	std::cout << "Press any key to continue" << std::endl;
	getch();//SE PONE PARA QUE SE VENA LOS DATOS ANTES DE INICIAR EL JUEGO
	//Reserva de memoria
	tablero_h = (float*)malloc(size_elementos);
	decisions_h = (float*)malloc(size_elementos);
	sum_points_h = (float*)malloc(size_elementos);
	sum_gaps_h = (float*)malloc(size_elementos); 
	movements_left_h = (float*)malloc(size_elementos);
	movements_left_aux_h = (float*)malloc(size_elementos);
	movements_performed_h = (float*)malloc(size_elementos);
	decisions_cpy_h = (float*)malloc(size_elementos);
	ia_tablero_h = (float*)malloc(size_elementos);
	ia_decisions_h = (float*)malloc(size_elementos);
	HANDLE_ERROR(cudaMalloc((void **)&tablero_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&decisions_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&sum_points_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&sum_gaps_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_left_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_left_aux_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_performed_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&decisions_cpy_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&ia_tablero_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&ia_decisions_d, size_elementos));
	//Asignación inicial de memoria
	memset(tablero_h, 0, size_elementos);
	memset(decisions_h, 0, size_elementos);
	memset(sum_points_h, 0, size_elementos);
	memset(sum_gaps_h, 0, size_elementos);
	memset(movements_left_h, 0, size_elementos);
	memset(movements_left_aux_h, 0, size_elementos);
	memset(movements_performed_h, 0, size_elementos);
	memset(decisions_cpy_h, 0, size_elementos);
	memset(ia_tablero_h, 0, size_elementos);
	memset(ia_decisions_h, 0, size_elementos);
	memset(score, 0, sizeof(int)*LIVES);
	addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
	do {//BUCLE DE JUEGO
		if (move_done) {//Si el moviento es valido se actualiza la cabecera
			system("cls");//BORRADO DE LA PANTALLA
			std::cout << sidebar << std::endl;
			std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
			std::cout << "Score: " << score[lives-1] << std::endl;
			std::cout << sidebar << std::endl;
			std::cout << printTablero<float>(tablero_h, n_columnas, n_filas) << std::endl;
		}
		move_done = false;
		movement_to_perform = getch();//Permite ver la IA paso a paso, filtrar el primer caracter de las fechas y cambiar de modo o salir aunque estemos en modo IA
		if ((modo_ejecucion == 'a') && !((movement_to_perform == 'c') || (movement_to_perform == 'g') || (movement_to_perform == 'm') || (movement_to_perform == 'e'))) {
			movement_to_perform = 0;
			std::cout << movement_to_perform << std::endl;
			getch();
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
			HANDLE_ERROR(cudaMemcpy(decisions_cpy_d, decisions_cpy_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(ia_tablero_d, ia_tablero_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(ia_tablero_d, ia_decisions_h, size_elementos, cudaMemcpyHostToDevice));
			if (modo_ejecucion == 'm') {
				movement_to_perform = getch();
			} else {//IA
				if (RANDOM_IA) {
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
				} else {
					int ia_score[4];
					memset(ia_score, 0, sizeof(int)*4);
					for (int i = 0; i < 4; ++i) {
						switch (movement_to_perform) {//REALIZAR EL MOVIMENTO
						case 0:
							takeDecisionsV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
							check_CUDA_Error("DECISIONES V");
							cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
							check_CUDA_Error("CPY");
							moveV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("MOVE V");
							break;
						case 1:
							takeDecisionsH << <1, n_elementos, 1 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
							check_CUDA_Error("DECISIONES H");
							cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
							check_CUDA_Error("CPY");
							moveH << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
							check_CUDA_Error("MOVE H");
							break;
						case 2:
							flipV << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("FILIP V");
							takeDecisionsV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
							check_CUDA_Error("DECISIONES V");
							cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
							check_CUDA_Error("CPY");
							moveV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("MOVE V");
							flipV << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("FILIP V");
							break;
						case 3:
							flipH << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas);
							check_CUDA_Error("FILIP H");
							takeDecisionsH << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
							check_CUDA_Error("DECISIONES H");
							cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
							check_CUDA_Error("CPY");
							moveH << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
							check_CUDA_Error("MOVE H");
							flipH << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas);
							check_CUDA_Error("FILIP H");
							break;
						}
						//CALCULAR EL VALOR DE CADA MOVIENTO

						//ELEGIR EL MEJOR MOVIENTO
					}
				}
			}
			switch (movement_to_perform) {//REALIZAR EL MOVIMENTO
				case KEY_UP:
					takeDecisionsV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
					check_CUDA_Error("DECISIONES V");
					cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
					check_CUDA_Error("CPY");
					moveV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("MOVE V");
					break;
				case KEY_LEFT:
					takeDecisionsH << <1, n_elementos, 1 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
					check_CUDA_Error("DECISIONES H");
					cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
					check_CUDA_Error("CPY");
					moveH << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
					check_CUDA_Error("MOVE H");
					break;
				case KEY_DOWN:
					flipV << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("FILIP V");
					takeDecisionsV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
					check_CUDA_Error("DECISIONES V");
					cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
					check_CUDA_Error("CPY");
					moveV << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("MOVE V");
					flipV << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("FILIP V");
					break;
				case KEY_RIGHT:
					flipH << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas);
					check_CUDA_Error("FILIP H");
					takeDecisionsH << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
					check_CUDA_Error("DECISIONES H");
					cpyMatrix << <1, n_elementos, 0 >> > (decisions_d, decisions_cpy_d, n_elementos);
					check_CUDA_Error("CPY");
					moveH << <1, n_elementos, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas);
					check_CUDA_Error("MOVE H");
					flipH << <1, n_elementos, 0 >> > (tablero_d, n_elementos, n_columnas);
					check_CUDA_Error("FILIP H");
					break;
			}
			check_CUDA_Error("MOVER");			
			//SUMAR MOVIMIENTOS-->CAMBIAR POR COMPARAR MATRICES
			sumMovements << <1, n_elementos, 0 >> > (decisions_cpy_d, movements_performed_d, n_elementos, max_recursion);
			check_CUDA_Error("SUMA MOVIMIENTOS");
			HANDLE_ERROR(cudaMemcpy(movements_performed_h, movements_performed_d, size_elementos, cudaMemcpyDeviceToHost));
			if (movements_performed_h[0]) {
				//AÑADIR NUEVAS CASILLAS AL TABLERO DE FORMA ALEATORIA
				HANDLE_ERROR(cudaMemcpy(tablero_h, tablero_d, size_elementos, cudaMemcpyDeviceToHost));
				addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
				HANDLE_ERROR(cudaMemcpy(tablero_d, tablero_h, size_elementos, cudaMemcpyHostToDevice));
				//SUMA HUECOS
				sumGaps << <1, n_elementos, 0 >> > (tablero_d, sum_gaps_d, n_elementos, max_recursion);
				check_CUDA_Error("SUMA HUECOS");
				HANDLE_ERROR(cudaMemcpy(sum_gaps_h, sum_gaps_d, size_elementos, cudaMemcpyDeviceToHost));
				//QUEDAN MOVIMIENTOS?
				sumLeft << <1, n_elementos, 0 >> > (tablero_d, movements_left_aux_d, n_elementos, n_columnas, n_filas);
				check_CUDA_Error("MOVEMENTS LEFT AUX");
				sumMovements << <1, n_elementos, 0 >> > (movements_left_aux_d, movements_left_d, n_elementos, max_recursion);
				check_CUDA_Error("MOVEMENTS LEFT SUM");
				HANDLE_ERROR(cudaMemcpy(movements_left_h, movements_left_d, size_elementos, cudaMemcpyDeviceToHost));
				if ((sum_gaps_h[0] <= 0) && (movements_left_h[0] <= 0)) {//No quedan movimentos
					--lives;
					std::cout << sidebar << std::endl;
					std::cout << "Lives:" << lives << std::endl;
					std::cout << "TotalScore: " << sumArray(score, LIVES) << std::endl;
					std::cout << sidebar << std::endl;
					std::cout << "Pulse cualquier techa para continuar" << std::endl;
					memset(tablero_h, 0, size_elementos);
					addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
					getchar();
				} else {//Quedan movientos
						++round;
						move_done = true;
						//SUMAR PUNTOS
						sumPoints << <1, n_elementos, 0 >> > (decisions_cpy_d, sum_points_d, n_elementos, max_recursion);
						check_CUDA_Error("SUMA PUNTOS");
						HANDLE_ERROR(cudaMemcpy(sum_points_h, sum_points_d, size_elementos, cudaMemcpyDeviceToHost));
						score[lives - 1] += static_cast<int>(sum_points_h[0]);
				}
			} else {
				system("cls");//BORRADO DE LA PANTALLA
				std::cout << sidebar << std::endl;
				std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
				std::cout << "Score: " << score[lives - 1] << std::endl;
				std::cout << sidebar << std::endl;
				std::cout << printTablero<float>(tablero_h, n_columnas, n_filas) << std::endl;
				std::cout << sidebar << std::endl;
				std::cout << "Movimiento no valido" << std::endl;
				std::cout << sidebar << std::endl;
			}
		}
		if (movement_to_perform == 'm') { //Cambio de modo
			std::cout << "Escriba el nuevo modo [ a | m ]: ";
			std::cin >> modo_ejecucion;
			if ((modo_ejecucion != 'a') && (modo_ejecucion != 'm')) {
				std::cout << "Modo de ejecución incorrecto, por defecto manual" << std::endl;
				modo_ejecucion = 'm';
				move_done = true;
			}
		} else if (movement_to_perform == 'g') {//Guardado de datos
			std::string file_name;
			std::cout << "Escriba el nombre con el que guardar su partida: ";
			std::cin >> file_name;
			std::ofstream file;
			file.open(file_name, std::ios::out | std::ios::trunc | std::ios::binary);
			if (file.is_open()) {//Se guardan los datos en el archivo indicado
				file << n_columnas << " " << n_filas << " " << lives << " " << round << " ";
				for (int i = 0; i < LIVES; ++i) {
					file << score[i] << " ";
				}
				for (int i = 0; i < n_elementos; ++i) {
					file << tablero_h[i] << " ";
				}
			}
			file.close();
			std::cout << "Matriz guardada, puede seguir jugando" << std::endl;
		} else if (movement_to_perform == 'c') {//Carga de datos
			std::string file_name;
			std::cout << "Escriba el nombre de su partida a cargar: ";
			std::cin >> file_name;
			std::ifstream file (file_name, std::ios::in | std::ios::binary);
			if (file.is_open()) {//Se leen los datos del archivo indicado
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
				//Datos del tablero
				n_elementos = n_filas * n_columnas;
				size_elementos = sizeof(float) * n_elementos;
				max_recursion = static_cast<int>(std::ceil(std::log2(n_elementos)));
				//Liberación de memoria
				free(tablero_h);
				free(decisions_h);
				free(sum_points_h);
				free(sum_gaps_h);
				free(movements_left_h);
				free(movements_left_aux_h);
				free(movements_performed_h);
				free(decisions_cpy_h);
				free(ia_tablero_h);
				free(ia_decisions_h);
				HANDLE_ERROR(cudaFree(tablero_d));
				HANDLE_ERROR(cudaFree(decisions_d));
				HANDLE_ERROR(cudaFree(sum_points_d));
				HANDLE_ERROR(cudaFree(sum_gaps_d));
				HANDLE_ERROR(cudaFree(movements_left_d));
				HANDLE_ERROR(cudaFree(movements_left_aux_d));
				HANDLE_ERROR(cudaFree(movements_performed_d));
				HANDLE_ERROR(cudaFree(decisions_cpy_d));
				HANDLE_ERROR(cudaFree(ia_tablero_d));
				HANDLE_ERROR(cudaFree(ia_decisions_d));
				//Actualización de tamaños de los vectores
				tablero_h = (float*)malloc(size_elementos);
				decisions_h = (float*)malloc(size_elementos);
				sum_points_h = (float*)malloc(size_elementos);
				sum_gaps_h = (float*)malloc(size_elementos);
				movements_left_h = (float*)malloc(size_elementos);
				movements_left_aux_h = (float*)malloc(size_elementos);
				movements_performed_h = (float*)malloc(size_elementos);
				decisions_cpy_h = (float*)malloc(size_elementos);
				ia_tablero_h = (float*)malloc(size_elementos);
				ia_decisions_h = (float*)malloc(size_elementos);
				HANDLE_ERROR(cudaMalloc((void **)&tablero_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&decisions_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&sum_points_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&sum_gaps_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_left_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_left_aux_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_performed_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&decisions_cpy_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&ia_tablero_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&ia_decisions_d, size_elementos));
				memset(tablero_h, 0, size_elementos);
				memset(decisions_h, 0, size_elementos);
				memset(sum_points_h, 0, size_elementos);
				memset(sum_gaps_h, 0, size_elementos);
				memset(movements_left_h, 0, size_elementos);
				memset(movements_left_aux_h, 0, size_elementos);
				memset(movements_performed_h, 0, size_elementos);
				memset(decisions_cpy_h, 0, size_elementos);
				memset(ia_tablero_h, 0, size_elementos);
				memset(ia_decisions_h, 0, size_elementos);
				sidebar = replicateString("\xC4", static_cast<int>(n_columnas)*6+1);
				spaces = replicateString(" ", n_columnas);
				//Carga los datos del nuevo tablero
				for (int i = 0; i < n_elementos; ++i) {
					in >> tablero_h[i];
				}
				//Datos de inicio de nueva partida
				system("cls");
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
		//Se borra el contenido de los vectores para la siguiente iteración
		memset(decisions_h, 0, size_elementos);
		memset(sum_points_h, 0, size_elementos);
		memset(sum_gaps_h, 0, size_elementos);
		memset(movements_left_h, 0, size_elementos);
		memset(movements_left_aux_h, 0, size_elementos);
		memset(movements_performed_h, 0, size_elementos);
		memset(decisions_cpy_h, 0, size_elementos);
		memset(ia_tablero_h, 0, size_elementos);
		memset(ia_decisions_h, 0, size_elementos);
	} while (movement_to_perform!='e' && (lives > 0));
	//Datos de fin de partida
	system("cls");
	std::cout << sidebar << std::endl;
	std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << printTablero(tablero_h, n_filas, n_columnas) << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << "Game over!!!" << std::endl;
	std::cout << "TotalScore: " << sumArray<int>(score, LIVES) << std::endl;
	std::cout << sidebar << std::endl;
	//Liberación de memoria
	free(tablero_h);
	free(decisions_h);
	free(sum_points_h);
	free(sum_gaps_h);
	free(movements_left_h);
	free(movements_left_aux_h);
	free(movements_performed_h);
	free(decisions_cpy_h);
	free(ia_tablero_h);
	free(ia_decisions_h);
	HANDLE_ERROR(cudaFree(tablero_d));
	HANDLE_ERROR(cudaFree(decisions_d));
	HANDLE_ERROR(cudaFree(sum_points_d));
	HANDLE_ERROR(cudaFree(sum_gaps_d));
	HANDLE_ERROR(cudaFree(movements_left_d));
	HANDLE_ERROR(cudaFree(movements_left_aux_d));
	HANDLE_ERROR(cudaFree(movements_performed_d));
	HANDLE_ERROR(cudaFree(decisions_cpy_d));
	HANDLE_ERROR(cudaFree(ia_tablero_d));
	HANDLE_ERROR(cudaFree(ia_decisions_d));
	getch(); //Para evitar que se cierre la ventana
	return(0);
}

