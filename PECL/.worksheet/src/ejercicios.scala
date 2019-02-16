import java.util
import java.util.Scanner
import java.io.BufferedReader
import java.io.InputStreamReader

object ejercicios {;import org.scalaide.worksheet.runtime.library.WorksheetSupport._; def main(args: Array[String])=$execute{;$skip(280); 



		def programa():Unit = {
				val reader = new Scanner(System.in)
				val reader2 = new Scanner(System.in)
				println(reader)
				programa
				
		
		};System.out.println("""programa: ()Unit""");$skip(40); 



	val reader = new Scanner(System.in);System.out.println("""reader  : java.util.Scanner = """ + $show(reader ));$skip(44); 
	print("Introduce la dificultad (1,2 o 3)");$skip(36); 
	
	
	val numero = reader.nextInt();System.out.println("""numero  : Int = """ + $show(numero ));$skip(13); ;
	val col = 9;System.out.println("""col  : Int = """ + $show(col ));$skip(13); 
	val fil = 9;System.out.println("""fil  : Int = """ + $show(fil ));$skip(112); 
  def generarTablero(col:Int): List[Int] = col match{
		case 0 => Nil
		case _ => (0)::generarTablero(col-1)
	};System.out.println("""generarTablero: (col: Int)List[Int]""");$skip(289); 
  
  def poner(l:List[Int], color:Int, posicion:Int): List[Int]= posicion match{
  	case 1 => List(color)::: l.tail  //si la posicion coincide metemos el color con el resto de la lista
  	case _ => l.head:: poner(l.tail,color, (posicion-1)) //si no llamamos con una posicion menos
  	
  };System.out.println("""poner: (l: List[Int], color: Int, posicion: Int)List[Int]""");$skip(220); 
  
  def poner2(l:List[Int],color:Int): List[Int]={
  	val aleatorio = (Math.random()*(l.length+1)) //generamos un numero aleatorio
  	val a = aleatorio.toInt
  	poner(l,color,a) //lo metemos en la posicion generada
  };System.out.println("""poner2: (l: List[Int], color: Int)List[Int]""");$skip(4496); 
  
  
  def obtenerElementos(l:List[Int],pos:Int,fil:Int,col:Int, color:Int): List[Int]={
    var m = List(1,1)
  	if (pos%col == 0){ //si estamos en la primera columna (aunque la lista empiece por 1 nosotros lo consideramos por 0)
  		if(pos==0){  //si estamos en la primera fila
  			if (l(pos+1)== color|| l(pos+col)== color){ //si alguno de los elementos de la derecha o de abajo coinciden con el color
  				m = eliminar_aux(l,pos) //lo marcamos como eliminado
  				//buscamos la poscion o posiciones a eliminar
  				if(l(pos+1)== color){
  					m=eliminar_aux(m,pos+1)
  				}
  				if (l(pos+col)==color){
  						m=eliminar_aux(m,pos+col)
  				}
  				m
  			}
  			else{ //si ningun elemento coincide no podemos eliminar, asi que devolvemos la lista directamente
  				println("Error en la ficha seleccionada")
  				l
  			}
  		}
  		else if (pos >= (col*(fil-1))){ //si estamos en la ultima fil
  			if (l(pos+1)==color || l(pos-col)==color){
  				m=eliminar_aux(l,pos)
  				if(l(pos+1)==color){
  					m=eliminar_aux(m,pos+1)
  				}
  				if(l(pos-col)==color){
  					m=eliminar_aux(m,pos-col)
  				}
  				m
  			}
  			else{
  				println("Error en la ficha seleccionada")
  				l
  			}
  		}
  		else{ //si estamos en el medio
  			if(l(pos+1)==color||l(pos+col)==color||l(pos-col)==color){
  				m=eliminar_aux(l,pos)
  				if(l(pos+1)==color){
  					m=eliminar_aux(m,pos+1) //eliminamos una a la derecha
  				}
  				if(l(pos+col)==color){
  					m=eliminar_aux(m,pos+col) //eliminamos una hacia abajo
  				}
  				if(l(pos-col)==color){ //eliminamos una hacia arriba
  					m=eliminar_aux(m,pos-col)
  				}
  				m
  			}
  			else{
  				println("Error en la ficha seleccionada")
  				l
  			}
  		}
  	}
  	else if (pos<col){ //si estamos en la primera fila
  		if (pos==(col -1)){ //si estamos en la ultima columna
  			if(l(pos-1)==color || l(pos+col)==color){
  				m=eliminar_aux(l,pos)
  				if(l(pos-1)==color){
  					m=eliminar_aux(m,pos-1)
  				}
  				if(l(pos+col)==color){
  					m=eliminar_aux(m,pos+col)
  				}
  				m
  			}
				else{
					println("Error en la ficha seleccionada")
  				l
				}
  		}
  		else{ //si estamos en el medio
  			if (l(pos-1)==color || l(pos+1) == color || l(pos+col)==color){
  				m=eliminar_aux(l,pos)
  				if(l(pos-1)==color){
  					m=eliminar_aux(m,pos-1)
  				}
  				if(l(pos+1)==color){
  					m=eliminar_aux(m,pos+1)
  				}
  				if(l(pos+col)==color){
  					m=eliminar_aux(m,pos+col)
  				}
  			}
  			else{
  				println("Error en la ficha seleccionada")
  			}
  			m
  		}
  	}
  	else if (pos%col == (col-1)){ //si estamos en la ultima columna
  		if(pos==(l.length - 1)){ //si estamos en la ultima fila
  			if (l(pos-1)==color || l(pos-col)==color){
  				m=eliminar_aux(l,pos)
  				if(l(pos-1)==color){
  					m=eliminar_aux(m,pos-1) //eliminamos la posicion si coincide con el color
  				}
  				if(l(pos-col)==color){
  					m=eliminar_aux(m,pos-col)
  				}
  			}
  			else{
  				println("Error en la ficha seleccionada")
  			}
  			m
  		}
  		else{ //si estamos en el medio
  			if(l(pos-1)==color || l(pos+col)==color || l(pos-col)==color){
  				m=eliminar_aux(l,pos)
  				if(l(pos-1)==color){
  					m=eliminar_aux(m,pos-1)
  				}
  				if(l(pos+col)==color){
  					m=eliminar_aux(m,pos+col)
  				}
  				if(l(pos-col)==color){
  					m=eliminar_aux(m,pos-col)
  				}
  			}
  			else{
  				println("Error en la ficha seleccionada")
  			}
  			m
  		}
  	}
  	else if (pos>(col*(fil-1))){ //si estamos en la ultima fila y en el medio
  		if(l(pos-1)==color || l(pos+1)==color || l(pos-col)==color){
  			m=eliminar_aux(l,pos)
  			if(l(pos-1)==color){
  				m=eliminar_aux(m, pos-1)
  			}
  			if(l(pos+1)==color){
  				m=eliminar_aux(m,pos+1)
  			}
  			if(l(pos-col)==color){
  				m=eliminar_aux(m,pos-col)
  			}
  		}
  		else{
  			println("Error en la ficha seleccionada")
  		}
  		m
  	}
  	else{ //si estamos en el medio del tablero
  		if(l(pos+1)==color || l(pos-1)==color || l(pos+col)==color  || l(pos-col)==color){
  			println("Eliminamos ficha")
  			m = eliminar_aux(l,pos)
  			if(l(pos-1)==color){
  				m= eliminar_aux(m,pos-1)
  				if(l(pos+1)==color){
  					m = eliminar_aux(m,pos+1)
  					if(l(pos-col)==color){
  						m = eliminar_aux(m,pos-col)
  						if(l(pos+col)==color){
  							m = eliminar_aux(m,pos+col)
  						}
  					}
  				}
  			}
  		}
  		else{
  			println("Error en la ficha seleccionada")
  			l
  		}
  		m
  	}
  };System.out.println("""obtenerElementos: (l: List[Int], pos: Int, fil: Int, col: Int, color: Int)List[Int]""");$skip(81); 
 	
  def imprimirTablero(l:List[Int],col:Int) ={
  		imprimir_aux(l,col-1,0)
  };System.out.println("""imprimirTablero: (l: List[Int], col: Int)Unit""");$skip(303); 
  
  def imprimir_aux(l:List[Int],salto:Int,n:Int):Unit = {
  	if(l.isEmpty) println("")
  	else if(n==salto){
  	
  				print(l.head)
  				print("\t\n")
  				imprimir_aux(l.tail, salto, 0)
  				
  				
  		} else {
  			print(l.head)
  			print("\t")
  			imprimir_aux(l.tail, salto, n+1)
  		}
  };System.out.println("""imprimir_aux: (l: List[Int], salto: Int, n: Int)Unit""");$skip(356); 
  
   /* Sustituye los numeros aleatorios por 0s */
   def generarAle(l:List[Int]): List[Int] = {
   			if (l.isEmpty) l
   			else{
   				if(l.head==0) {
   					val aleatorio = (Math.random()*(5)) + 1
  					val a = aleatorio.toInt
  					List(a):::generarAle(l.tail)
   				}else{
   					List(l.head):::generarAle(l.tail)
   				}
   			
   			}
   };System.out.println("""generarAle: (l: List[Int])List[Int]""");$skip(215); 
   
   //obtenemos el color que queremos eliminar
   def obtenerColor(l:List[Int], pos:Int): Int={
   		if(pos==0){
   		 val color = l(pos)
   		color
   		}
    	else{
    	 obtenerColor(l.tail,pos-1)
    	}
   };System.out.println("""obtenerColor: (l: List[Int], pos: Int)Int""");$skip(517); 
                                              
    /* Elimina el color que haya en una posición determinada */
    def eliminarPos(l:List[Int], fil_eli:Int, col_eli:Int, col:Int, fil:Int):List[Int] = {
    		val pos_vector = col_eli + (fil_eli - 1) * col - 1
    		//obtenemos el valor del color
    		val color = obtenerColor(l, pos_vector)
    		println("El color es " + color)
    		//obtenemos los valores que tiene a los lados y, si coinciden, eliminamos
    		obtenerElementos(l,pos_vector,fil,col,color)
    };System.out.println("""eliminarPos: (l: List[Int], fil_eli: Int, col_eli: Int, col: Int, fil: Int)List[Int]""");$skip(165); 
    
    //eliminamos la ficha
    def eliminar_aux(l:List[Int],n:Int):List[Int] = {
    	if(n==0) List(0):::l.tail
    	else l.head::eliminar_aux(l.tail,n-1)
    };System.out.println("""eliminar_aux: (l: List[Int], n: Int)List[Int]""");$skip(46); 
    
   	val matriz = generarTablero(col*fil);System.out.println("""matriz  : List[Int] = """ + $show(matriz ));$skip(32); 
   	val m5 = generarAle(matriz);System.out.println("""m5  : List[Int] = """ + $show(m5 ));$skip(27); 
	  imprimirTablero(m5,col);$skip(92); 
  	val m6 = eliminarPos(m5, 3,3, col, fil);System.out.println("""m6  : List[Int] = """ + $show(m6 ));$skip(27);    //estas posiciones tiene que darlas el usuario
  	imprimirTablero(m6,col);$skip(27); 
  	val m7 = generarAle(m6);System.out.println("""m7  : List[Int] = """ + $show(m7 ));$skip(27); 
	  imprimirTablero(m7,col)}
  
}
