# Taller Final de Inteligencia Computacional — UPTC
**Integrantes:** 
* Cristian Javier Gómez Pérez
* Juan David León Numpaque
* Miguel Felipe Silva Guisao
* Yulian Alexis Tobar Ríos
  
**Semilla aleatoria de reproducibilidad:** `3119`

---

## Enlaces Directos a Notebooks Ejecutables (Google Colab)
* **Punto 2 — Máquinas de Soporte Vectorial (SVM):** https://colab.research.google.com/drive/1m2N0QKaL5XfnJzsPQHSnmNp5Z148n0CA?usp=sharing
* **Punto 4 — Redes Neuronales Convolucionales (CNN):** https://colab.research.google.com/drive/1U_wAHbg77AtDniCiZ6QVIZ0VVXXASrr5?usp=sharing


---

## Estructura del Repositorio

### 1. `punto2_svm/` — Clasificación con SVM (*Shoe vs Sandal vs Boot*)
* `silva_leon_tobar_gomez_svm.ipynb`: Notebook completo con preprocesamiento (`StandardScaler -> PCA 80% -> SVC`), entrenamiento de las 5 configuraciones, matrices de confusión y marcas de tiempo.
* `silva_leon_tobar_gomez_tabla_experimentos_svm.csv`: Resultados comparativos de los kernels Lineal, RBF y Polinomial (grado 2).
* `modelos/`: Los 5 modelos entrenados serializados en formato `.joblib` listos para inferencia.

### 2. `punto3_algoritmos_geneticos/` — Neuroevolución NEAT en *Super Mario World*
* `scripts_lua/`: Scripts adaptados (`silva_leon_tovar_gomez_escenarioA.lua`, `escenarioB.lua` y `generalizacion.lua`) para BizHawk 2.3.1 (núcleo Snes9x).
* `modelos/`: Poblaciones entrenadas (`backup.51.YI1.state.pool` y `backup.28.YI2.state.pool`) y puntos de guardado (`YI1.State`, `YI2.State`).
* `datos/`, `analisis/` y `evidencias/`: Registros CSV por generación, script de métricas, gráficas de convergencia y capturas con sello de tiempo.

### 3. `punto4_cnn/` — Clasificación de Imágenes con CNN (*Shoe vs Sandal vs Boot*)
* `Silva_Leon_Gomez_Tobar_cnn.ipynb`: Notebook completo con EDA, Baseline MLP, arquitecturas CNN progresivas (con Batch Normalization y Data Augmentation), análisis de errores y recarga de modelos.
* `modelos/`: Pesos entrenados en formato `.h5` (`Silva_Leon_Gomez_Tobar_baseline.h5` y variantes CNN) junto con `clases.json`.
