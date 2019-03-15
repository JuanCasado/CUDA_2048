
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

//FLECHAS
#define KEY_UP 72
#define KEY_DOWN 80
#define KEY_LEFT 75
#define KEY_RIGHT 77
#define LIVES 5//CANTIDAD DE VIDAS
#define RANDOM_IA 1//MODO DE LA IA
#define SCALE 1
//COLORES
#define RESET "\033[0m"
#define IRed "\033[0;101m"      
#define IGreen "\033[0;102m"    
#define IYellow "\033[0;103m"   
#define IBlue "\033[0;104m"     
#define IPurple "\033[0;105m"   
#define ICyan "\033[0;106m"     
#define Red "\033[1;91m"     
#define Green "\033[1;92m"   
#define Yellow "\033[1;93m"  
#define Blue "\033[1;94m"    
#define Purple "\033[1;95m"  
#define Cyan "\033[1;96m"    
#define IWhite "\033[0;107m" 
#define White "\033[1;97m" 

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
__global__ void flipH (float *tablero, float *flip, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	int look = (nc - col - 1) + row * nc;
	if ((id < size) && (look < size) && (col < nc) && (row < nf)) {
		flip[id] = tablero[look];
	}
}
/*
Convierte la matriz en su simétrica por el eje Horizontal
La matriz es tanto de entrada como de salida
Se utiliza para hacer el movimiento vertical hacia abajo
*/
__global__ void flipV(float *tablero, float *flip, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	int look = col + (nf - row - 1) * nc;
	if ((id < size) && (look < size) && (col < nc) && (row < nf)) {
		flip[id] = tablero[look];
	}
}


/*
Realiza los el movimiento horizontal (izquierda) en el tablero según la matriz de decisiones
Pone en result los valores de tablero desplazados tanto como se indique en jump
*/
__global__ void moveH(float *tablero, float *jump, float *result, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		float value = tablero[id];
		int offset = col - jump[id];
		int future_pos = (offset)+row * nc;
		if (future_pos >= 0) {
			if (value) {
				result[future_pos] = value;
			}
		}
	}
}

/*
Realiza los el movimiento verical (arriba) en el tablero según la matriz de decisiones
Pone en result los valores de tablero desplazados tanto como se indique en jump
*/
__global__ void moveV(float *tablero, float *jump, float *result, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		float value = tablero[id];
		int offset = row - jump[id];
		int future_pos = col + (offset)* nc;
		if (future_pos >= 0) {
			if (value) {
				result[future_pos] = value;
			}
		}
	}
}

/*
Dice los ceros que hay desde cada casilla al final del tablero hacia la izquierda
Se utiliza para saber cuanto desplazar los valores en move
*/
__global__ void zeroCountH(float *tablero, float *jump, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	int count = 0;
	if ((id < size) && (col < nc) && (row < nf)) {
		for (int i = 1; i <= col; ++i) {
			if (!tablero[id - i]) {
				++count;
			}
		}
		jump[id] += count;
	}
}

/*
ice los ceros que hay desde cada casilla al final del tablero hacia la abajo
Se utiliza para saber cuanto desplazar los valores en move
*/
__global__ void zeroCountV(float *tablero, float *jump, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	int count = 0;
	if ((id < size) && (col < nc) && (row < nf)) {
		for (int i = 1; i <= row; ++i) {
			if (!tablero[id - i * nc]) {
				++count;
			}
		}
		jump[id] += count;
	}
}

/*
Pone un uno en aquellas casillas que de deban borrar para realizar un movimiento (izquierda) según como
indique la matriz de decisiones
*/
__global__ void createDeleterH(float *tablero, float *decisions, float *out, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		if (decisions[id]) {
			int i = 1;
			while (!tablero[id - i]) {
				++i;
			}
			//printf("id: %d,def: %d", id, id-i);
			out[id - i] = 1;
		}
	}
}

/*
Pone un uno en aquellas casillas que de deban borrar para realizar un movimiento (abajo) según como
indique la matriz de decisiones
*/
__global__ void createDeleterV(float *tablero, float *decisions, float *out, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		if (decisions[id]) {
			int i = nc;
			while (!tablero[id - i]) {
				i += nc;
			}
			out[id - i] = 1;
		}
	}
}

/*
Sobre tablero se borra aquellas casillas indicadas por mask y se pone lo que haya en decisions
Debido a cómo se generan mask y decisions nunca coinciden con un valor en la misma posicion
*/
__global__ void deleteValues(float *tablero, float *mask, float *decisions, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		if (decisions[id]) {
			tablero[id] = decisions[id];
		}
		else if (mask[id]) {
			tablero[id] = 0;
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
__global__ void takeDecisionsH(float *tablero, float *decisions,int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	int index = id;
	int colum_index = col;
	float value = 0;
	float new_value = 0;
	bool perform_movement = false;
	bool different_value_found = false;
	if ((id < size) && (col < nc) && (row < nf)) {
		value = tablero[id];
	}
	while ((colum_index > 0) && !different_value_found) {
		--index;
		--colum_index;
		if ((id < size) && (col < nc) && (row < nf)) {
			new_value = tablero[index];
			if (new_value == value) {
				perform_movement = !perform_movement;
			}
			if ((new_value != 0) && (new_value != value)) {
				different_value_found = true;
			}
		}
	}
	if (perform_movement) {
		if ((id < size) && (col < nc) && (row < nf)) {
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
__global__ void takeDecisionsV(float *tablero, float *decisions,int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	int index = id;
	int row_index = row;
	float value = 0;
	float new_value = 0;
	bool perform_movement = false;
	bool different_value_found = false;
	if ((id < size) && (col < nc) && (row < nf)) {
		value = tablero[id];
	}
	while ((row_index > 0) && !different_value_found) {
		index -= nc;
		--row_index;
		if ((index < size) && (col < nc) && (row < nf)) {
			new_value = tablero[index];
			if (new_value == value) {
				perform_movement = !perform_movement;
			}
			if ((new_value != 0) && (new_value != value)) {
				different_value_found = true;
			}
		}
	}
	if (perform_movement) {
		if ((id < size) && (col < nc) && (row < nf)) {
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
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		result[id] = 0;
		if (tablero[id]) {
			if (((col + 1) < nc) && (tablero[id] == tablero[id + 1])) {
				result[id] = 1;
			}
			if (((col - 1) > 0) && (tablero[id] == tablero[id - 1])) {
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
__global__ void sumPoints(float *decisions, float *sum_result, int size, int nc, int nf, int step) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if (step == 0){
		if ((id < size) && (col < nc) && (row < nf)) {
			sum_result[id] = decisions[id];
		}
	}
	int active_thread = powf(2, step + 1);
	int pair_id = powf(2, step);
	if (((id % active_thread) == 0) && ((id + pair_id) < size)) {
		if ((id < size) && (col < nc) && (row < nf)) {
			if (((id + pair_id) < size) && (col < nc) && (row < nf)) {
				float suma = sum_result[id] + sum_result[id + pair_id];
				sum_result[id] = suma;
			}
		}
	}
}

/*
Cuenta los elementos idénticos a 0 en una matriz
Se utiliza para saber cuantos huecos quedan en el tablero
*/
__global__ void sumGaps(float *decisions, float *sum_result, int size, int nc, int nf, int step) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if (step == 0) {
		if ((id < size) && (col < nc) && (row < nf)) {
			sum_result[id] = (float)(decisions[id] == 0.0f);
		}
	}
	int active_thread = powf(2, step + 1);
	int pair_id = powf(2, step);
	if (((id % active_thread) == 0) && ((id + pair_id) < size)) {
		if ((id < size) && (col < nc) && (row < nf)) {
			if (((id + pair_id) < size) && (col < nc) && (row < nf)) {
				float suma = sum_result[id] + sum_result[id + pair_id];
				sum_result[id] = suma;
			}
		}
	}
}

/*
Cuenta la cantidad de elementos distintos de 0 que hay en una matriz
Se utiliza para saber si un moviento realiza cambios sobre el tablero
*/
__global__ void sumMovements(float *decisions, float *sum_result, int size, int nc, int nf, int step) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if (step == 0) {
		if ((id < size) && (col < nc) && (row < nf)) {
			sum_result[id] = (float)(decisions[id] != 0.0f);
		}
	}
	int active_thread = powf(2, step + 1);
	int pair_id = powf(2, step);
	if (((id % active_thread) == 0) && ((id + pair_id) < size)) {
		if ((id < size) && (col < nc) && (row < nf)) {
			if (((id + pair_id) < size) && (col < nc) && (row < nf)) {
				float suma = sum_result[id] + sum_result[id + pair_id];
				sum_result[id] = suma;
			}
		}
	}
}

/*
Copia el contenido de una matriz en otra
Se utiliza para no perder la matriz de decisiones al hacer un movimiento y
para guardar el tablero y comprobar si despés de un moviento ha cambiado
*/
__global__ void cpyMatrix(float *matriz, float *copia, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		copia[id] = matriz[id];
	}
}

/*
Comprueba si la matriz primera es igual a la segunada y pone el resultado en la segunada
Se utiliza para saber si el tablero ha cambiado
*/
__global__ void hasChanged (float *matriz, float *copia, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	float resultado = 0;
	if ((id < size) && (col < nc) && (row < nf)) {
		resultado = (matriz[id] == copia[id]);
		copia[id] = resultado;
	}
}

/*
Pone todos los elemntos de la matriz al valor indicado
*/
__global__ void setValue(float *matriz, int size, int nc, int nf, float value) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		matriz[id] = value;
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
			switch (num) {
			case 0: {ss << White; break; }
			case 2: {ss << Red; break; }
			case 4: {ss << Green; break; }
			case 8: {ss << Yellow; break; }
			case 16: {ss << Blue; break; }
			case 32: {ss << Purple; break; }
			case 64: {ss << Cyan; break; }
			case 128: {ss << IRed; break; }
			case 256: {ss << IGreen; break; }
			case 512: {ss << IYellow; break; }
			case 1024: {ss << IBlue; break; }
			case 2048: {ss << IPurple; break; }
			case 4096: {ss << ICyan; break; }
			case 8192: {ss << IWhite; break; }
			default: {ss << IWhite; break; }
			}
			ss << std::setw(5) << centered(num==0?"":std::to_string(num)) << RESET << "\xBA";
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
		tablero[available_positions[random]] = (static_cast<T>(std::rand() % 2) + 1) * ((takes > 8) ? 4 : 4);
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

/*
Maximo indice de un array en la CPU
Se utiliza SOLO para calcular el maximo de los puntos de la IA en un array de 4 elementos
*/
template <class T>
__host__ T maxArray(T *arr, int len) {
	T max = 0;
	int max_index = 0;
	for (int i = 0; i < len; ++i) {
		if (arr[i] > max) {
			max = arr[i];
			max_index = i;
		}
	}
	return max_index;
}

__host__ int conversionPotencia(int value) {
	return pow(2,floor(log2(floor(sqrt(value)))));
}

__global__ void kernelExamen(float *entrada, float *salida, int size, int nc, int nf) {
	int col = threadIdx.x + blockIdx.x * blockDim.x;
	int row = threadIdx.y + blockIdx.y * blockDim.y;
	int id = col + row * nc;
	if ((id < size) && (col < nc) && (row < nf)) {
		float value = entrada[id];
		if (value) {
			salida[id] = value;
			if (((col + 1) < nc) && ((row + 1) < nf)) {
				salida[id + 1 + nc] = value;
			}
			if (((col - 1) >= 0) && ((row + 1) < nf)) {
				salida[id - 1 + nc] = value;
			}
			if (((col + 1) < nc) && ((row - 1) >= 0)) {
				salida[id + 1 - nc] = value;
			}
			if (((col - 1) >= 0) && ((row - 1) >= 0)) {
				salida[id - 1 - nc] = value;
			}
		}
	}
}


int main(int argc, char **argv) {
	CONSOLE_FONT_INFOEX font;
	font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {15,21},FF_DONTCARE,FW_NORMAL };
	SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE), true, &font); //Control de la fuente
	ShowWindow(GetConsoleWindow(), SW_SHOWMAXIMIZED);//Consola en pantalla completa
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
	float *tablero_cpy_h;//Copia el tablero para saber si el nuevo es igual que el anterior
	float *tablero_cpy_d;
	float *decisions_cpy_h;//Copia de las decisiones pues se pierden al realizar el moviento
	float *decisions_cpy_d;
	float *ia_tablero_h;
	float *ia_tablero_d;
	float *ia_decisions_h;
	float *ia_decisions_d;
	float *flip_aux_h;//Matriz auxiliar para los volteos
	float *flip_aux_d;
	float *movements_aux_h;//Auxiliar de los movimientos
	float *movements_aux_d;
	float *decisions_aux_h;//Auxiliar de las decisiones
	float *decisions_aux_d;
	float *delete_mask_d;
	float *delete_mask_h;
	float *jumps_h;//Saltos desde cada posicion para hacer un movimiento
	float *jumps_d;
	float *tablero_aux_h;
	float *tablero_aux_d;
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
	bool examen = false;
	std::cout << std::endl;
	std::cout << "Multiprocesor count: " << prop.multiProcessorCount << std::endl;
	std::cout << "Max Threads per multiprocesor: " << prop.maxThreadsPerMultiProcessor << std::endl;
	std::cout << "Max Threads per block: " << prop.maxThreadsPerBlock << std::endl << std::endl;
	//Se cargan los datos de inicio de partida
	if (argc < 4) {
		std::cout << "Modo de ejecucion [ a | m ]: ";
		std::cin >> modo_ejecucion;
		std::cout << "Cuantos elementos iniciales quiere [ 1 = 8 | 2 = 15 | 3 = EXAMEN]: ";
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
		}break;
		case 3: {
			elementos_iniciales = 15;
			examen = true;
		} break;
	}
	n_elementos = n_filas * n_columnas;
	size_elementos = sizeof(float) * n_elementos;
	max_recursion = static_cast<int>(std::ceil(std::log2(n_elementos)));
	int TILE = min(conversionPotencia(n_elementos), conversionPotencia(prop.maxThreadsPerBlock));
	dim3 dimGrid(ceil(static_cast<float>(n_columnas) / static_cast<float>(TILE)), ceil(static_cast<float>(n_filas) / static_cast<float>(TILE)));
	dim3 dimBlock(TILE, TILE);
	sidebar = replicateString("\xC4", static_cast<int>(n_columnas) * 6 + 1);
	spaces = replicateString(" ", n_columnas);
	//Datos de inicio de nueva partida
	std::cout << std::endl;
	std::cout << "Columnas : " << n_columnas << " | Filas: " << n_filas << " -> Elementos: " << n_elementos << " | Max recursion: " << max_recursion << std::endl;
	std::cout << "BloquesX : " << dimGrid.x << " | BloquesY: " << dimGrid.y << " -> TILE: " << TILE << std::endl;
	std::cout << "Modo: " << ((modo_ejecucion == 'a') ? "automatico" : "manual") << " | Gasto de hilos: " << (static_cast<int>(dimGrid.x*dimGrid.y*TILE*TILE) - n_elementos) << std::endl << std::endl;
	if (n_elementos > (prop.maxThreadsPerBlock*prop.maxThreadsPerMultiProcessor*prop.multiProcessorCount)) {
		std::cout << "La matriz es demasiado grande!!!" << std::endl;
		std::cout << "Press any key to continue" << std::endl;
		getch();
		exit(-1);
	}
	std::cout << "Press any key to continue" << std::endl;
	getch();//SE PONE PARA QUE SE VENA LOS DATOS ANTES DE INICIAR EL JUEGO
	system("cls");
	if (SCALE) {
		if (n_elementos <= 16) {
			font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {40,58},FF_DONTCARE,FW_NORMAL };
		}
		else if (n_elementos <= 64) {
			font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {24,32},FF_DONTCARE,FW_NORMAL };
		}
		else if (n_elementos <= 256) {
			font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {12,20},FF_DONTCARE,FW_NORMAL };
		}
		else if (n_elementos <= 1024) {
			font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {8,14},FF_DONTCARE,FW_NORMAL };
		} else if (n_elementos <= 3200) {
			font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {6,9},FF_DONTCARE,FW_NORMAL };
		} else{
			font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {4,6},FF_DONTCARE,FW_NORMAL };
		}
		SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE), true, &font); //Control de la fuente
		ShowWindow(GetConsoleWindow(), SW_RESTORE);//Consola en pantalla completa
		ShowWindow(GetConsoleWindow(), SW_SHOWMAXIMIZED);//Consola en pantalla completa
	}
	//Reserva de memoria
	tablero_h = (float*)malloc(size_elementos);
	decisions_h = (float*)malloc(size_elementos);
	sum_points_h = (float*)malloc(size_elementos);
	sum_gaps_h = (float*)malloc(size_elementos); 
	movements_left_h = (float*)malloc(size_elementos);
	movements_left_aux_h = (float*)malloc(size_elementos);
	movements_performed_h = (float*)malloc(size_elementos);
	tablero_cpy_h = (float*)malloc(size_elementos);
	decisions_cpy_h = (float*)malloc(size_elementos);
	ia_tablero_h = (float*)malloc(size_elementos);
	ia_decisions_h = (float*)malloc(size_elementos);
	flip_aux_h = (float*)malloc(size_elementos);
	movements_aux_h = (float*)malloc(size_elementos);
	decisions_aux_h = (float*)malloc(size_elementos);
	delete_mask_h = (float*)malloc(size_elementos);
	jumps_h = (float*)malloc(size_elementos);
	tablero_aux_h = (float*)malloc(size_elementos);
	HANDLE_ERROR(cudaMalloc((void **)&tablero_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&decisions_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&sum_points_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&sum_gaps_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_left_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_left_aux_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_performed_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&tablero_cpy_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&decisions_cpy_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&ia_tablero_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&ia_decisions_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&flip_aux_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&movements_aux_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&decisions_aux_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&delete_mask_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&jumps_d, size_elementos));
	HANDLE_ERROR(cudaMalloc((void **)&tablero_aux_d, size_elementos));
	//Asignación inicial de memoria
	memset(tablero_h, 0, size_elementos);
	memset(decisions_h, 0, size_elementos);
	memset(sum_points_h, 0, size_elementos);
	memset(sum_gaps_h, 0, size_elementos);
	memset(movements_left_h, 0, size_elementos);
	memset(movements_left_aux_h, 0, size_elementos);
	memset(movements_performed_h, 0, size_elementos);
	memset(tablero_cpy_h, 0, size_elementos);
	memset(decisions_cpy_h, 0, size_elementos);
	memset(ia_tablero_h, 0, size_elementos);
	memset(ia_decisions_h, 0, size_elementos);
	memset(flip_aux_h, 0, size_elementos);
	memset(movements_aux_h, 0, size_elementos);
	memset(decisions_aux_h, 0, size_elementos);
	memset(delete_mask_h, 0, size_elementos);
	memset(jumps_h, 0, size_elementos);
	memset(score, 0, sizeof(int)*LIVES);
	if (examen) {//PARA HACER LAS CAPTURAS
		addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
		std::cout << printTablero(tablero_h, n_columnas, n_filas) << std::endl;
		//SUBIR A DEVICE
		HANDLE_ERROR(cudaMemcpy(tablero_d, tablero_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(decisions_d, decisions_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(sum_points_d, sum_points_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(sum_gaps_d, sum_gaps_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(movements_left_d, movements_left_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(movements_left_d, movements_left_aux_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(movements_performed_d, movements_performed_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(tablero_cpy_d, decisions_cpy_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(decisions_cpy_d, decisions_cpy_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(ia_tablero_d, ia_tablero_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(ia_decisions_d, ia_decisions_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(flip_aux_d, flip_aux_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(movements_aux_d, movements_aux_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(decisions_aux_d, decisions_aux_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(delete_mask_d, delete_mask_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(jumps_d, jumps_h, size_elementos, cudaMemcpyHostToDevice));
		HANDLE_ERROR(cudaMemcpy(tablero_aux_d, tablero_aux_h, size_elementos, cudaMemcpyHostToDevice));
		//KERNEL NUEVO
		kernelExamen << <dimGrid, dimBlock, 0 >> > (tablero_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
		cpyMatrix << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, tablero_d, n_elementos, n_columnas, n_filas);
		//HANDLE_ERROR(cudaMemcpy(tablero_h, tablero_d, size_elementos, cudaMemcpyDeviceToHost));
		//std::cout << printTablero(tablero_h, n_columnas, n_filas) << std::endl;
		//MOVER IZQUIERDA
		takeDecisionsH << <dimGrid, dimBlock, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_elementos);
		check_CUDA_Error("DECISIONES H");
		cpyMatrix << <dimGrid, dimBlock, 0 >> > (decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
		check_CUDA_Error("COPIA DECISIONES");
		setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
		setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
		setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
		createDeleterH << <dimGrid, dimBlock, 0 >> > (tablero_d, decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
		deleteValues << <dimGrid, dimBlock, 0 >> > (tablero_d, delete_mask_d, decisions_d, n_elementos, n_columnas, n_filas);
		zeroCountH << <dimGrid, dimBlock, 0 >> > (tablero_d, jumps_d, n_elementos, n_columnas, n_filas);
		setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
		moveH << <dimGrid, dimBlock, 0 >> > (tablero_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
		cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, tablero_d, n_elementos, n_columnas, n_filas);
		check_CUDA_Error("MOVE H");
		//HANDLE_ERROR(cudaMemcpy(tablero_h, tablero_d, size_elementos, cudaMemcpyDeviceToHost));
		//std::cout << printTablero(tablero_h, n_columnas, n_filas) << std::endl;
		elementos_iniciales = 8;
		addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
		//std::cout << printTablero(tablero_h, n_columnas, n_filas) << std::endl;
	}
	else {
		addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
	}
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
		if (examen) {
			movement_to_perform = 0;
		}else{
			movement_to_perform = getch();//Permite ver la IA paso a paso, filtrar el primer caracter de las fechas y cambiar de modo o salir aunque estemos en modo IA
			if ((modo_ejecucion == 'a') && !((movement_to_perform == 'c') || (movement_to_perform == 'g') || (movement_to_perform == 'm') || (movement_to_perform == 'e'))) {
				movement_to_perform = 0;
				std::cout << movement_to_perform << std::endl;
				getch();
			}
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
			HANDLE_ERROR(cudaMemcpy(tablero_cpy_d, decisions_cpy_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(decisions_cpy_d, decisions_cpy_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(ia_tablero_d, ia_tablero_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(ia_decisions_d, ia_decisions_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(flip_aux_d, flip_aux_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(movements_aux_d, movements_aux_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(decisions_aux_d, decisions_aux_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(delete_mask_d, delete_mask_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(jumps_d, jumps_h, size_elementos, cudaMemcpyHostToDevice));
			HANDLE_ERROR(cudaMemcpy(tablero_aux_d, tablero_aux_h, size_elementos, cudaMemcpyHostToDevice));
			if (examen) {
				movement_to_perform = KEY_LEFT;
			}
			else if (modo_ejecucion == 'm') {
				movement_to_perform = getch();
			}
			else {//IA
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
						cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
						check_CUDA_Error("COPIA TABLERO IA");
						cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_d, tablero_cpy_d, n_elementos, n_columnas, n_filas);
						check_CUDA_Error("COPIA DECISIONES IA");
						switch (i) {//REALIZAR EL MOVIMENTO
						case 0:
							takeDecisionsV << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("DECISIONES V");
							cpyMatrix << <dimGrid, dimBlock, 0 >> > (ia_decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("CPY");
							setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
							createDeleterV << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, ia_decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
							deleteValues << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, delete_mask_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							zeroCountV << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, jumps_d, n_elementos, n_columnas, n_filas);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							moveV << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, ia_tablero_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
							cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("MOVE V");
							break;
						case 1:
							takeDecisionsH << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("DECISIONES H");
							cpyMatrix << <dimGrid, dimBlock, 0 >> > (ia_decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("CPY");
							setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
							createDeleterH << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, ia_decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
							deleteValues << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, delete_mask_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							zeroCountH << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, jumps_d, n_elementos, n_columnas, n_filas);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							moveH << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
							cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("MOVE H");
							break;
						case 2:
							flipV << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, flip_aux_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("FILIP V");
							takeDecisionsV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("DECISIONES V");
							cpyMatrix << <dimGrid, dimBlock, 0 >> > (ia_decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("CPY");
							setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
							createDeleterV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, ia_decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
							deleteValues << <dimGrid, dimBlock, 0 >> > (flip_aux_d, delete_mask_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							zeroCountV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, n_elementos, n_columnas, n_filas);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							moveV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("MOVE V");
							flipV << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("FILIP V");
							break;
						case 3:
							flipH << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, flip_aux_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("FILIP H");
							takeDecisionsH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, ia_decisions_d, n_elementos, n_columnas, n_elementos);
							check_CUDA_Error("DECISIONES H");
							cpyMatrix << <dimGrid, dimBlock, 0 >> > (ia_decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("CPY");
							setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (flip_aux_d, n_elementos, n_columnas, n_filas, 0);
							setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
							createDeleterH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, ia_decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
							deleteValues << <dimGrid, dimBlock, 0 >> > (flip_aux_d, delete_mask_d, ia_decisions_d, n_elementos, n_columnas, n_filas);
							zeroCountH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, n_elementos, n_columnas, n_filas);
							setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
							moveH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("MOVE H");
							flipH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
							check_CUDA_Error("FILIP H");
							break;
						}
						check_CUDA_Error("MOVER");
						//CALCULAR EL VALOR DE CADA MOVIENTO
						for (int step = 0; step < max_recursion; ++step) {
							sumMovements << <dimGrid, dimBlock, 0 >> > (decisions_cpy_d, sum_points_d, n_elementos, n_columnas, n_filas, step);
							check_CUDA_Error("SUM POINTS");
						}
						HANDLE_ERROR(cudaMemcpy(sum_points_h, sum_points_d, size_elementos, cudaMemcpyDeviceToHost));
						//EVALUAR SI EL IA_TABLERO TIENE MOVIMIENTO Y SI DECISIONES_CPY ES BUENO O NO 
						hasChanged << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, tablero_cpy_d, n_elementos, n_filas, n_columnas);
						check_CUDA_Error("HAS CHANGED");
						for (int step = 0; step < max_recursion; ++step) {
							sumGaps << <dimGrid, dimBlock, 0 >> > (tablero_cpy_d, movements_performed_d, n_elementos, n_columnas, n_filas, step);
							check_CUDA_Error("SUM GAPS");
						}
						HANDLE_ERROR(cudaMemcpy(movements_performed_h, movements_performed_d, size_elementos, cudaMemcpyDeviceToHost));
						//SUMA HUECOS
						for (int step = 0; step < max_recursion; ++step) {
							sumGaps << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, sum_gaps_d, n_elementos, n_columnas, n_filas, step);
							check_CUDA_Error("SUMA HUECOS");
						}
						HANDLE_ERROR(cudaMemcpy(sum_gaps_h, sum_gaps_d, size_elementos, cudaMemcpyDeviceToHost));
						//QUEDAN MOVIMIENTOS?
						sumLeft << <dimGrid, dimBlock, 0 >> > (tablero_d, movements_left_aux_d, n_elementos, n_columnas, n_filas);
						check_CUDA_Error("MOVEMENTS LEFT AUX");
						for (int step = 0; step < max_recursion; ++step) {
							sumMovements << <dimGrid, dimBlock, 0 >> > (movements_left_aux_d, movements_left_d, n_elementos, n_columnas, n_filas, step);
							check_CUDA_Error("MOVEMENTS LEFT SUM");
						}
						HANDLE_ERROR(cudaMemcpy(movements_left_h, movements_left_d, size_elementos, cudaMemcpyDeviceToHost));
						ia_score[i] = (sum_gaps_h[0]?1:0)* (movements_performed_h[0]?1:0) * ((sum_gaps_h[0]?sum_gaps_h[0]:1) + sum_points_h[0]*2);
						//BORRAR LO USADO
						setValue << <dimGrid, dimBlock, 0 >> > (sum_points_d, n_elementos, n_columnas, n_filas, 0);
						setValue << <dimGrid, dimBlock, 0 >> > (movements_performed_d, n_elementos, n_columnas, n_filas, 0);
						setValue << <dimGrid, dimBlock, 0 >> > (sum_gaps_d, n_elementos, n_columnas, n_filas, 0);
						setValue << <dimGrid, dimBlock, 0 >> > (movements_left_aux_d, n_elementos, n_columnas, n_filas, 0);
						setValue << <dimGrid, dimBlock, 0 >> > (movements_left_d, n_elementos, n_columnas, n_filas, 0);
						setValue << <dimGrid, dimBlock, 0 >> > (ia_decisions_d, n_elementos, n_columnas, n_filas, 0);
						check_CUDA_Error("SET 0");
					}
					//ELEGIR EL MEJOR MOVIENTO
					switch (maxArray(ia_score, 4)) {
					case 0:
						movement_to_perform = KEY_UP;
						break;
					case 1:
						movement_to_perform = KEY_LEFT;
						break;
					case 2:
						movement_to_perform = KEY_DOWN;
						break;
					case 3:
						movement_to_perform = KEY_RIGHT;
						break;
					}	
				}
			}
			cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_d, tablero_cpy_d, n_elementos, n_columnas, n_filas);
			check_CUDA_Error("COPIA TABLERO");
			switch (movement_to_perform) {//REALIZAR EL MOVIMENTO
				case KEY_UP:
					takeDecisionsV << <dimGrid, dimBlock, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("DECISIONES V");
					cpyMatrix << <dimGrid, dimBlock, 0 >> > (decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("COPIA DECISIONES");
					setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
					createDeleterV << <dimGrid, dimBlock, 0 >> > (tablero_d, decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
					deleteValues << <dimGrid, dimBlock, 0 >> > (tablero_d, delete_mask_d, decisions_d, n_elementos, n_columnas, n_filas);
					zeroCountV << <dimGrid, dimBlock, 0 >> > (tablero_d, jumps_d, n_elementos, n_columnas, n_filas);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					moveV << <dimGrid, dimBlock, 0 >> > (tablero_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
					cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, tablero_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("MOVE V");
					break;
				case KEY_LEFT:
					if (examen) {
						kernelExamen << <dimGrid, dimBlock, 0 >> > (tablero_d, ia_tablero_d, n_elementos, n_columnas, n_filas);
						cpyMatrix << <dimGrid, dimBlock, 0 >> > (ia_tablero_d, tablero_d, n_elementos, n_columnas, n_filas);
					}
					takeDecisionsH << <dimGrid, dimBlock, 0 >> > (tablero_d, decisions_d, n_elementos, n_columnas, n_elementos);
					check_CUDA_Error("DECISIONES H");
					cpyMatrix << <dimGrid, dimBlock, 0 >> > (decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("COPIA DECISIONES");
					setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
					createDeleterH << <dimGrid, dimBlock, 0 >> > (tablero_d, decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
					deleteValues << <dimGrid, dimBlock, 0 >> > (tablero_d, delete_mask_d, decisions_d, n_elementos, n_columnas, n_filas);
					zeroCountH << <dimGrid, dimBlock, 0 >> > (tablero_d, jumps_d, n_elementos, n_columnas, n_filas);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					moveH << <dimGrid, dimBlock, 0 >> > (tablero_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
					cpyMatrix << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, tablero_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("MOVE H");
					break;
				case KEY_DOWN:
					flipV << <dimGrid, dimBlock, 0 >> > (tablero_d, flip_aux_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("FILIP V");
					takeDecisionsV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, decisions_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("DECISIONES V");
					cpyMatrix << <dimGrid, dimBlock, 0 >> > (decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("COPIA DECISIONES");
					setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
					createDeleterV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
					deleteValues << <dimGrid, dimBlock, 0 >> > (flip_aux_d, delete_mask_d, decisions_d, n_elementos, n_columnas, n_filas);
					zeroCountV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, n_elementos, n_columnas, n_filas);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					moveV << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("MOVE V");
					flipV << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, tablero_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("FILIP V");
					break;
				case KEY_RIGHT:
					flipH << <dimGrid, dimBlock, 0 >> > (tablero_d, flip_aux_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("FILIP H");
					takeDecisionsH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, decisions_d, n_elementos, n_columnas, n_elementos);
					check_CUDA_Error("DECISIONES H");
					cpyMatrix << <dimGrid, dimBlock, 0 >> > (decisions_d, decisions_cpy_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("COPIA DECISIONES");
					setValue << <dimGrid, dimBlock, 0 >> > (jumps_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					setValue << <dimGrid, dimBlock, 0 >> > (delete_mask_d, n_elementos, n_columnas, n_filas, 0);
					createDeleterH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, decisions_d, delete_mask_d, n_elementos, n_columnas, n_filas);
					deleteValues << <dimGrid, dimBlock, 0 >> > (flip_aux_d, delete_mask_d, decisions_d, n_elementos, n_columnas, n_filas);
					zeroCountH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, n_elementos, n_columnas, n_filas);
					setValue << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, n_elementos, n_columnas, n_filas, 0);
					moveH << <dimGrid, dimBlock, 0 >> > (flip_aux_d, jumps_d, tablero_aux_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("MOVE H");
					flipH << <dimGrid, dimBlock, 0 >> > (tablero_aux_d, tablero_d, n_elementos, n_columnas, n_filas);
					check_CUDA_Error("FILIP H");
					break;
			}
			check_CUDA_Error("MOVER");	
			//EVALUR SI EL MOVIENTO HA PRODUCIDO UN CAMBIO EN LA MATRIZ
			hasChanged << <dimGrid, dimBlock, 0 >>>(tablero_d, tablero_cpy_d, n_elementos, n_columnas, n_filas);
			check_CUDA_Error("HAS CHANGED");
			for (int step = 0; step < max_recursion; ++step) {
				sumGaps << <dimGrid, dimBlock, 0 >> > (tablero_cpy_d, movements_performed_d, n_elementos, n_columnas, n_filas, step);
				check_CUDA_Error("SUM GAPS");
			}
			HANDLE_ERROR(cudaMemcpy(movements_performed_h, movements_performed_d, size_elementos, cudaMemcpyDeviceToHost));
			if (movements_performed_h[0]) {
				//AÑADIR NUEVAS CASILLAS AL TABLERO DE FORMA ALEATORIA
				HANDLE_ERROR(cudaMemcpy(tablero_h, tablero_d, size_elementos, cudaMemcpyDeviceToHost));
				addRandom<float>(tablero_h, elementos_iniciales, n_elementos);
				HANDLE_ERROR(cudaMemcpy(tablero_d, tablero_h, size_elementos, cudaMemcpyHostToDevice));
				//SUMA HUECOS
				for (int step = 0; step < max_recursion; ++step) {
					sumGaps << <dimGrid, dimBlock, 0 >> > (tablero_d, sum_gaps_d, n_elementos, n_columnas, n_filas, step);
					check_CUDA_Error("SUMA HUECOS");
				}
				HANDLE_ERROR(cudaMemcpy(sum_gaps_h, sum_gaps_d, size_elementos, cudaMemcpyDeviceToHost));
				//QUEDAN MOVIMIENTOS?
				sumLeft << <dimGrid, dimBlock, 0 >> > (tablero_d, movements_left_aux_d, n_elementos, n_columnas, n_filas);
				check_CUDA_Error("MOVEMENTS LEFT AUX");
				for (int step = 0; step < max_recursion; ++step) {
					sumMovements << <dimGrid, dimBlock, 0 >> > (movements_left_aux_d, movements_left_d, n_elementos, n_columnas, n_filas, step);
					check_CUDA_Error("MOVEMENTS LEFT SUM");
				}
				HANDLE_ERROR(cudaMemcpy(movements_left_h, movements_left_d, size_elementos, cudaMemcpyDeviceToHost));
				if ((sum_gaps_h[0] <= 0) && (movements_left_h[0] <= 0)) {//No quedan movimentos
					--lives;
					system("cls");//BORRADO DE LA PANTALLA
					std::cout << sidebar << std::endl;
					std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
					std::cout << "Score: " << score[lives - 1] << std::endl;
					std::cout << sidebar << std::endl;
					std::cout << printTablero<float>(tablero_h, n_columnas, n_filas) << std::endl;
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
						for (int step = 0; step < max_recursion; ++step) {
							sumPoints << <dimGrid, dimBlock, 0 >> > (decisions_cpy_d, sum_points_d, n_elementos, n_columnas, n_filas, step);
							check_CUDA_Error("SUMA PUNTOS");
						}
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
				free(tablero_cpy_h);
				free(decisions_cpy_h);
				free(ia_tablero_h);
				free(ia_decisions_h);
				free(flip_aux_h);
				free(movements_aux_h);
				free(decisions_aux_h);
				free(delete_mask_h);
				free(jumps_h);
				free(tablero_aux_h);
				HANDLE_ERROR(cudaFree(tablero_d));
				HANDLE_ERROR(cudaFree(decisions_d));
				HANDLE_ERROR(cudaFree(sum_points_d));
				HANDLE_ERROR(cudaFree(sum_gaps_d));
				HANDLE_ERROR(cudaFree(movements_left_d));
				HANDLE_ERROR(cudaFree(movements_left_aux_d));
				HANDLE_ERROR(cudaFree(movements_performed_d));
				HANDLE_ERROR(cudaFree(tablero_cpy_d));
				HANDLE_ERROR(cudaFree(decisions_cpy_d));
				HANDLE_ERROR(cudaFree(ia_tablero_d));
				HANDLE_ERROR(cudaFree(ia_decisions_d));
				HANDLE_ERROR(cudaFree(flip_aux_d));
				HANDLE_ERROR(cudaFree(movements_aux_d));
				HANDLE_ERROR(cudaFree(decisions_aux_d));
				HANDLE_ERROR(cudaFree(delete_mask_d));
				HANDLE_ERROR(cudaFree(jumps_d));
				HANDLE_ERROR(cudaFree(tablero_aux_d));
				//Actualización de tamaños de los vectores
				tablero_h = (float*)malloc(size_elementos);
				decisions_h = (float*)malloc(size_elementos);
				sum_points_h = (float*)malloc(size_elementos);
				sum_gaps_h = (float*)malloc(size_elementos);
				movements_left_h = (float*)malloc(size_elementos);
				movements_left_aux_h = (float*)malloc(size_elementos);
				movements_performed_h = (float*)malloc(size_elementos);
				tablero_cpy_h = (float*)malloc(size_elementos);
				decisions_cpy_h = (float*)malloc(size_elementos);
				ia_tablero_h = (float*)malloc(size_elementos);
				ia_decisions_h = (float*)malloc(size_elementos);
				flip_aux_h = (float*)malloc(size_elementos);
				movements_aux_h = (float*)malloc(size_elementos);
				decisions_aux_h = (float*)malloc(size_elementos);
				delete_mask_h = (float*)malloc(size_elementos);
				jumps_h = (float*)malloc(size_elementos);
				tablero_aux_h = (float*)malloc(size_elementos);
				HANDLE_ERROR(cudaMalloc((void **)&tablero_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&decisions_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&sum_points_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&sum_gaps_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_left_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_left_aux_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_performed_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&tablero_cpy_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&decisions_cpy_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&ia_tablero_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&ia_decisions_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&flip_aux_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&movements_aux_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&decisions_aux_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&delete_mask_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&jumps_d, size_elementos));
				HANDLE_ERROR(cudaMalloc((void **)&tablero_aux_d, size_elementos));
				memset(tablero_h, 0, size_elementos);
				memset(decisions_h, 0, size_elementos);
				memset(sum_points_h, 0, size_elementos);
				memset(sum_gaps_h, 0, size_elementos);
				memset(movements_left_h, 0, size_elementos);
				memset(movements_left_aux_h, 0, size_elementos);
				memset(movements_performed_h, 0, size_elementos);
				memset(tablero_cpy_h, 0, size_elementos);
				memset(decisions_cpy_h, 0, size_elementos);
				memset(ia_tablero_h, 0, size_elementos);
				memset(ia_decisions_h, 0, size_elementos);
				memset(flip_aux_h, 0, size_elementos);
				memset(movements_aux_h, 0, size_elementos);
				memset(decisions_aux_h, 0, size_elementos);
				memset(delete_mask_h, 0, size_elementos);
				memset(jumps_h, 0, size_elementos);
				memset(tablero_aux_h, 0, size_elementos);
				sidebar = replicateString("\xC4", static_cast<int>(n_columnas)*6+1);
				spaces = replicateString(" ", n_columnas);
				//Carga los datos del nuevo tablero
				for (int i = 0; i < n_elementos; ++i) {
					in >> tablero_h[i];
				}
				if (SCALE) {
					if (n_elementos <= 16) {
						font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {40,58},FF_DONTCARE,FW_NORMAL };
					}
					else if (n_elementos <= 64) {
						font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {24,32},FF_DONTCARE,FW_NORMAL };
					}
					else if (n_elementos <= 256) {
						font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {12,20},FF_DONTCARE,FW_NORMAL };
					}
					else if (n_elementos <= 1024) {
						font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {8,14},FF_DONTCARE,FW_NORMAL };
					}
					else if (n_elementos <= 3200) {
						font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {6,9},FF_DONTCARE,FW_NORMAL };
					}
					else {
						font = CONSOLE_FONT_INFOEX{ sizeof(CONSOLE_FONT_INFOEX),0, COORD {4,6},FF_DONTCARE,FW_NORMAL };
					}
					SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE), true, &font); //Control de la fuente
					ShowWindow(GetConsoleWindow(), SW_RESTORE);//Consola en pantalla completa
					ShowWindow(GetConsoleWindow(), SW_MAXIMIZE);//Consola en pantalla completa
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
				std::cout << printTablero(tablero_h, n_columnas, n_filas) << std::endl;
				std::cout << sidebar << std::endl;
				if (n_elementos > (prop.maxThreadsPerBlock*prop.maxThreadsPerMultiProcessor*prop.multiProcessorCount)) {
					std::cout << "La matriz es demasiado grande!!!" << std::endl;
					std::cout << "Press any key to continue" << std::endl;
					getch();
					exit(-1);
				}
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
		memset(tablero_cpy_h, 0, size_elementos);
		memset(decisions_cpy_h, 0, size_elementos);
		memset(ia_tablero_h, 0, size_elementos);
		memset(ia_decisions_h, 0, size_elementos);
		memset(flip_aux_h, 0, size_elementos);
		memset(movements_aux_h, 0, size_elementos);
		memset(decisions_aux_h, 0, size_elementos);
		memset(delete_mask_h, 0, size_elementos);
		memset(jumps_h, 0, size_elementos);
		memset(tablero_aux_h, 0, size_elementos);
	} while (movement_to_perform!='e' && (lives > 0));
	//PUNTUACION DE TODAS LAS PARTIDAS
	int total_score = 0;
	std::ifstream input("_total_score_", std::ios::in | std::ios::binary);
	if (input.is_open()) {//Se leen los datos anteriores
		std::string line;
		std::getline(input, line);
		std::istringstream in(line);
		in >> total_score;
	}
	input.close();
	total_score += sumArray<int>(score, LIVES);
	std::ofstream output;
	output.open("_total_score_", std::ios::out | std::ios::trunc | std::ios::binary);
	if (output.is_open()) {//Se guardan los datos en el archivo indicado
		output << total_score;
	}
	output.close();
	//Datos de fin de partida
	system("cls");
	std::cout << sidebar << std::endl;
	std::cout << "Round: " << round << spaces << "Lives :" << lives << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << printTablero(tablero_h, n_columnas, n_filas) << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << "Game over!!!" << std::endl;
	std::cout << "TotalScore: " << sumArray<int>(score, LIVES) << std::endl;
	std::cout << sidebar << std::endl;
	std::cout << "GlobalScore: " << total_score << std::endl;
	std::cout << sidebar << std::endl;
	//Liberación de memoria
	free(tablero_h);
	free(decisions_h);
	free(sum_points_h);
	free(sum_gaps_h);
	free(movements_left_h);
	free(movements_left_aux_h);
	free(movements_performed_h);
	free(tablero_cpy_h);
	free(decisions_cpy_h);
	free(ia_tablero_h);
	free(ia_decisions_h);
	free(flip_aux_h);
	free(movements_aux_h);
	free(decisions_aux_h);
	free(delete_mask_h);
	free(jumps_h);
	free(tablero_aux_h);
	HANDLE_ERROR(cudaFree(tablero_d));
	HANDLE_ERROR(cudaFree(decisions_d));
	HANDLE_ERROR(cudaFree(sum_points_d));
	HANDLE_ERROR(cudaFree(sum_gaps_d));
	HANDLE_ERROR(cudaFree(movements_left_d));
	HANDLE_ERROR(cudaFree(movements_left_aux_d));
	HANDLE_ERROR(cudaFree(movements_performed_d));
	HANDLE_ERROR(cudaFree(tablero_cpy_d));
	HANDLE_ERROR(cudaFree(decisions_cpy_d));
	HANDLE_ERROR(cudaFree(ia_tablero_d));
	HANDLE_ERROR(cudaFree(ia_decisions_d));
	HANDLE_ERROR(cudaFree(flip_aux_d));
	HANDLE_ERROR(cudaFree(movements_aux_d));
	HANDLE_ERROR(cudaFree(decisions_aux_d));
	HANDLE_ERROR(cudaFree(delete_mask_d));
	HANDLE_ERROR(cudaFree(jumps_d));
	HANDLE_ERROR(cudaFree(tablero_aux_d));
	getch(); //Para evitar que se cierre la ventana
	return(0);
}

