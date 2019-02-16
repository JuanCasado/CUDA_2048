import java.util
import java.util.Scanner
import java.io.BufferedReader
import java.io.InputStreamReader

object ejercicios {



		def programa():Unit = {
				val reader = new Scanner(System.in)
				val reader2 = new Scanner(System.in)
				println(reader)
				programa
				
		
		}                                 //> programa: ()Unit



	val reader = new Scanner(System.in)       //> reader  : java.util.Scanner = java.util.Scanner[delimiters=\p{javaWhitespace
                                                  //| }+][position=0][match valid=false][need input=false][source closed=false][sk
                                                  //| ipped=false][group separator=\.][decimal separator=\,][positive prefix=][neg
                                                  //| ative prefix=\Q-\E][positive suffix=][negative suffix=][NaN string=\Qï¿½\E][
                                                  //| infinity string=\Qâˆž\E]
	print("Introduce la dificultad (1,2 o 3)")//> Introduce la dificultad (1,2 o 3)-
	
	
	
	val numero = reader.nextInt();
	val col = 9
	val fil = 9
  def generarTablero(col:Int): List[Int] = col match{
		case 0 => Nil
		case _ => (0)::generarTablero(col-1)
	}
  
  def poner(l:List[Int], color:Int, posicion:Int): List[Int]= posicion match{
  	case 1 => List(color)::: l.tail  //si la posicion coincide metemos el color con el resto de la lista
  	case _ => l.head:: poner(l.tail,color, (posicion-1)) //si no llamamos con una posicion menos
  	
  }
  
  def poner2(l:List[Int],color:Int): List[Int]={
  	val aleatorio = (Math.random()*(l.length+1)) //generamos un numero aleatorio
  	val a = aleatorio.toInt
  	poner(l,color,a) //lo metemos en la posicion generada
  }
  
  
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
  }
 	
  def imprimirTablero(l:List[Int],col:Int) ={
  		imprimir_aux(l,col-1,0)
  }
  
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
  }
  
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
   }
   
   //obtenemos el color que queremos eliminar
   def obtenerColor(l:List[Int], pos:Int): Int={
   		if(pos==0){
   		 val color = l(pos)
   		color
   		}
    	else{
    	 obtenerColor(l.tail,pos-1)
    	}
   }
                                              
    /* Elimina el color que haya en una posición determinada */
    def eliminarPos(l:List[Int], fil_eli:Int, col_eli:Int, col:Int, fil:Int):List[Int] = {
    		val pos_vector = col_eli + (fil_eli - 1) * col - 1
    		//obtenemos el valor del color
    		val color = obtenerColor(l, pos_vector)
    		println("El color es " + color)
    		//obtenemos los valores que tiene a los lados y, si coinciden, eliminamos
    		obtenerElementos(l,pos_vector,fil,col,color)
    }
    
    //eliminamos la ficha
    def eliminar_aux(l:List[Int],n:Int):List[Int] = {
    	if(n==0) List(0):::l.tail
    	else l.head::eliminar_aux(l.tail,n-1)
    }
    
   	val matriz = generarTablero(col*fil)
   	val m5 = generarAle(matriz)
	  imprimirTablero(m5,col)
  	val m6 = eliminarPos(m5, 3,3, col, fil)   //estas posiciones tiene que darlas el usuario
  	imprimirTablero(m6,col)
  	val m7 = generarAle(m6)
	  imprimirTablero(m7,col)
  
}