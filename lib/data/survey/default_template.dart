import 'template.dart';

/// Plantilla inicial "Levantamiento eléctrico FV".
///
/// El orden de secciones sigue el recorrido de los levantamientos técnicos de
/// SolarGrade (REY01202, REY00607); cada evidencia indica la carpeta y el
/// prefijo que marca "Instrucciones de llenado de carpetas".
TemplateDef defaultElectricTemplate() {
  const yes = 'Sí';
  const no = 'No';
  const sfvYes = ShowIf(questionId: 'existe', equals: yes);

  return TemplateDef(
    id: 'tpl-levantamiento-electrico-fv',
    name: 'Levantamiento eléctrico FV',
    type: 'Viabilidad fotovoltaica',
    sections: [
      // ------------------------------------------------------------------ 1
      SectionDef(id: 's_info', title: 'Información principal', icon: 'info', groups: [
        GroupDef(id: 'g_datos', title: 'Datos generales', questions: [
          _text('nave', 'Nombre de la nave / cliente', req: true),
          _single('techo', 'Tipo de techo o recubrimiento',
              ['TPO', 'Lámina galvanizada', 'Losa de concreto', 'Multitecho', 'Otro'],
              req: true),
          _number('altura_cumbrera', 'Altura de nave (cumbrera)', 'm', req: true),
          _number('altura_costados', 'Altura de nave (costados)', 'm', req: true),
          _photo('croquis', 'Imagen satelital o croquis del sitio', Folders.sitio, 'CROQUIS_SITIO',
              req: true,
              hint: 'Indica norte, accesos, acometida, transformador y tableros principales. '
                  'Puedes importar la captura del dron o del mapa.'),
          _doc('recibo', 'Recibo de luz CFE (ambos lados)', Folders.sitio, 'RECIBO_CFE',
              req: true,
              cat: 'recibo_cfe',
              hint: 'Legible: número de servicio y medidor, tarifa, demanda contratada y desglose.'),
          _long('obs', 'Observaciones adicionales'),
        ]),
      ]),

      // ------------------------------------------------------------------ 2
      SectionDef(id: 's_subestacion', title: 'Subestación', icon: 'bolt', groups: [
        GroupDef(
          id: 'g_transformador',
          title: 'Transformador',
          repeatable: true,
          instanceLabel: 'Transformador',
          questions: [
            _single('tipo', 'Tipo de transformador', ['Pedestal', 'Subestación', 'Poste', 'Otro'],
                req: true),
            _single('conexion', 'Tipo de conexión', ['Δ-Y', 'Δ-Δ', 'Y-Δ', 'Y-Y'], req: true),
            _number('kva', 'Potencia', 'kVA', req: true),
            _number('v_primaria', 'Tensión primaria (A.T. / M.T.)', 'V', req: true),
            _text('v_secundaria', 'Tensión secundaria (B.T.)', req: true, hint: 'Ej. 480/277'),
            _number('impedancia', 'Impedancia', '%Z', req: true),
            _number('cond_fase', 'Conductores por fase (lado secundario)', ''),
            _text('calibre', 'Calibre y material de conductores F + N + GND'),
            _number('dist_espadas', 'Distancia entre espadas', 'cm'),
            _text('garganta', 'Profundidad y ancho de la garganta'),
            _photo('placa', 'Placa de datos', Folders.acometida, '{INSTANCIA}_PLACA',
                req: true, hint: 'Que se lea capacidad en kVA, voltajes e impedancia.'),
            _photo('generales', 'Fotos generales: conectores, aislamiento y gabinete', Folders.acometida,
                '{INSTANCIA}_GENERAL',
                req: true, min: 2),
            _photo('cableado', 'Cableado y terminales del secundario', Folders.acometida,
                '{INSTANCIA}_CABLEADO'),
            _doc('termografia', 'Termografía (archivo nativo de la cámara térmica)', Folders.acometida,
                '{INSTANCIA}_TERMOGRAFIA',
                hint: 'Sube el archivo original de la cámara, no una captura .png/.jpg.'),
            _scale('diam_tuberia', 'Diámetro de tubería de salida hacia tablero principal', 'in'),
            _photo('ubicacion', 'Croquis de ubicación del transformador', Folders.acometida,
                '{INSTANCIA}_UBICACION'),
            _long('obs', 'Observaciones adicionales'),
          ],
        ),
        GroupDef(
          id: 'g_tablero',
          title: 'Tableros',
          repeatable: true,
          instanceLabel: 'Tablero',
          firstInstanceLabel: 'Tablero Principal',
          questions: [
            _text('alimentado_por', '¿Qué lo alimenta?', hint: 'Ej. Transformador 1 / Tablero Principal'),
            _single('tipo', 'Tipo de tablero',
                ['Tipo gabinete', 'Distribución I-Line', 'Autosoportado', 'Distribución NQ / NF', 'Otro'],
                req: true),
            _text('catalogo', 'No. de catálogo / modelo', req: true),
            _text('tension', 'Tensión nominal de trabajo', req: true, hint: 'Ej. 480Y/277 V'),
            _number('corriente', 'Corriente nominal (ampacidad de barras)', 'A', req: true),
            _text('cond_entrada', 'Conductores de alimentación (calibre, material, HxF)'),
            _yesNo('itm_mismo', '¿ITM principal sobre el mismo tablero?', req: true),
            _text('itm_modelo', 'Modelo del ITM principal'),
            _number('itm_a', 'ITM principal · capacidad nominal', 'A', req: true),
            _number('itm_ka', 'ITM principal · capacidad de corto circuito', 'kA', req: true),
            _yesNo('espacio_fv', '¿Espacios disponibles para ITM FV?', req: true),
            _number('mediciones_bt', 'Cantidad de mediciones en B.T.', ''),
            _yesNo('medidores_digitales', '¿Cuenta con medidores digitales?'),
            _number('v_ff', 'Tensión fase-fase', 'V', req: true),
            _number('v_fn', 'Tensión fase-neutro', 'V', req: true),
            _number('v_ft', 'Tensión fase-tierra', 'V', req: true),
            _number('i_l1', 'Corriente L1', 'A', req: true),
            _number('i_l2', 'Corriente L2', 'A', req: true),
            _number('i_l3', 'Corriente L3', 'A', req: true),
            _photo('lecturas', 'Lecturas en multímetro o pinza amperimétrica', '${Folders.tableros}/{INSTANCIA}',
                '{INSTANCIA}_LECTURAS',
                req: true),
            _photo('cerrado', 'Vista general externa (cerrado)', '${Folders.tableros}/{INSTANCIA}',
                '{INSTANCIA}_CERRADO',
                req: true),
            _photo('abierto', 'Vista general (abierto) y directorio de cargas',
                '${Folders.tableros}/{INSTANCIA}', '{INSTANCIA}_ABIERTO',
                req: true),
            _photo('itm', 'Interruptores principal y derivados', '${Folders.tableros}/{INSTANCIA}',
                '{INSTANCIA}_ITM',
                req: true, hint: 'Que se aprecie el amperaje y la capacidad de corto circuito.'),
            _photo('cableado', 'Cableado interno, peinado, calibre y barra de tierra física',
                '${Folders.tableros}/{INSTANCIA}', '{INSTANCIA}_CABLEADO'),
            _photo('canalizacion', 'Trayectoria de canalización que lo alimenta',
                '${Folders.tableros}/{INSTANCIA}', '{INSTANCIA}_CANALIZACION'),
            _doc('termografia', 'Termografía del tablero, interruptores y empalmes',
                '${Folders.tableros}/{INSTANCIA}', '{INSTANCIA}_TERMOGRAFIA',
                hint: 'Archivo nativo de la cámara, marcando el punto de medición.'),
            _scale('diam_tuberia', 'Diámetro de tubería de alimentación', 'in'),
            _long('obs', 'Observaciones adicionales'),
          ],
        ),
        GroupDef(id: 'g_cuarto', title: 'Cuarto eléctrico / área eléctrica', questions: [
          _single('ubicacion', '¿El área eléctrica está al exterior o al interior?', ['Exterior', 'Interior'],
              req: true),
          _yesNo('unifilar', '¿Cuenta con diagrama unifilar?', req: true),
          _doc('unifilar_doc', 'Diagrama unifilar actual', Folders.documentacion, 'DIAGRAMA_UNIFILAR',
              req: true, cat: 'unifilar', showIf: const ShowIf(questionId: 'unifilar', equals: yes)),
          _photo('unifilar_mano', 'Diagrama unifilar a mano alzada', Folders.documentacion,
              'DIAGRAMA_UNIFILAR_MANO_ALZADA',
              req: true,
              showIf: const ShowIf(questionId: 'unifilar', equals: no),
              hint: 'Transformador (tensiones, Z), conductores HxF, tablero principal, ITM y kA, '
                  'barras y cada ITM derivado.'),
          _yesNo('planta', '¿El cliente cuenta con planta de emergencia?', req: true),
          _photo('planta_fotos', 'Planta de emergencia y transferencia automática', Folders.tableros,
              'PLANTA_EMERGENCIA',
              req: true, showIf: const ShowIf(questionId: 'planta', equals: yes)),
          _long('planta_conexion', '¿Cómo está conectada la planta? (indicarlo en el DU)',
              showIf: const ShowIf(questionId: 'planta', equals: yes)),
          _yesNo('interc_tablero', '¿Posible punto de interconexión en tablero?', req: true),
          _yesNo('interc_trafo', '¿Posible punto de interconexión en transformador?', req: true),
          _yesNo('espacio_dentro', '¿Espacio para gabinetes FV dentro del cuarto eléctrico?', req: true),
          _yesNo('espacio_fuera', '¿Espacio para gabinetes FV fuera del cuarto eléctrico?', req: true),
          _photo('espacio_fotos', 'Fotos del espacio disponible para gabinetes FV', Folders.tableros,
              'ESPACIO_GABINETES_FV',
              req: true),
          _long('obs', 'Observaciones adicionales'),
        ]),
      ]),

      // ------------------------------------------------------------------ 3
      SectionDef(id: 's_medicion', title: 'Medición', icon: 'meter', groups: [
        GroupDef(id: 'g_cfe', title: 'Medición CFE', questions: [
          _photo('acometida', 'Acometida: líneas de M.T. y transición a B.T.', Folders.acometida, 'ACOMETIDA',
              req: true),
          _single('tipo_medicion', 'Medición actual del cliente', ['Media tensión', 'Baja tensión', 'Otro'],
              req: true),
          _text('medidor', 'Número de medidor CFE', req: true),
          _photo('medidor_foto', 'Carátula del medidor con lectura visible', Folders.acometida, 'MEDIDOR_CFE',
              req: true),
          _scale('clientes', '¿Cuántos clientes tiene la nave?', ''),
          _yesNo('varias', '¿Cuenta con más de una medición CFE en el edificio?', req: true),
          _long('clientes_medidores', 'Nombre de cada cliente y su número de medidor',
              req: true, showIf: const ShowIf(questionId: 'varias', equals: yes)),
          _photo('ubicacion', 'Croquis de ubicación de la medición', Folders.acometida, 'MEDICION_UBICACION'),
          _long('obs', 'Observaciones adicionales'),
        ]),
        GroupDef(id: 'g_internos', title: 'Mediciones internas', questions: [
          _yesNo('hay', '¿Existen medidores internos?', req: true),
          _number('cantidad', 'Cantidad de medidores internos', '',
              req: true, showIf: const ShowIf(questionId: 'hay', equals: yes)),
          _long('que_miden', '¿A quién o qué mide cada medidor interno?',
              req: true, showIf: const ShowIf(questionId: 'hay', equals: yes)),
          _photo('fotos', 'Fotos de los medidores internos', Folders.acometida, 'MEDIDOR_INTERNO',
              showIf: const ShowIf(questionId: 'hay', equals: yes)),
        ]),
      ]),

      // ------------------------------------------------------------------ 4
      SectionDef(id: 's_cubierta', title: 'Cubierta', icon: 'roof', groups: [
        GroupDef(id: 'g_cubierta', title: 'Equipamiento y estado de cubierta', questions: [
          _photo('dron', 'Tomas aéreas: techumbre completa, obstáculos, accesos y sombras', Folders.dron,
              'DRON_CUBIERTA',
              req: true, hint: 'Importa las fotos del dron o toma las que puedas desde el techo.'),
          _photo('obstaculos', 'Medidas de obstáculos y equipos (pretiles, tragaluces, A/A)', Folders.dron,
              'OBSTACULOS'),
          _multi('antenas', '¿Antenas o pararrayos en cubierta?', ['Antenas', 'Pararrayos', 'N/A'], req: true),
          _yesNo('pretil', '¿Existe pretil?', req: true),
          _number('pretil_altura', 'Altura del pretil', 'm',
              req: true, showIf: const ShowIf(questionId: 'pretil', equals: yes)),
          _photo('pretil_fotos', 'Ubicación y altura del pretil', Folders.dron, 'PRETIL',
              showIf: const ShowIf(questionId: 'pretil', equals: yes)),
          _single('impermeabilizacion', 'Estado de la impermeabilización', ['Bueno', 'Regular', 'Malo'],
              req: true),
          _text('lamina', 'Tipo de lámina / losa'),
          _text('aislamiento', 'Grosor de aislamiento'),
          _text('inclinacion', 'Inclinación y orientación', hint: 'Ej. 2 aguas, 5°, orientación sur'),
          _photo('techo', 'Fotos a nivel de techo', Folders.dron, 'CUBIERTA', req: true, min: 2),
          _yesNo('hallazgo', '¿Cubierta en mal estado o insegura?', req: true),
          _long('hallazgo_desc', 'Describe el hallazgo de cubierta',
              req: true, showIf: const ShowIf(questionId: 'hallazgo', equals: yes)),
          _photo('hallazgo_fotos', 'Evidencia del hallazgo de cubierta', Folders.adicionales, 'HALLAZGO_CUBIERTA',
              req: true, showIf: const ShowIf(questionId: 'hallazgo', equals: yes)),
          _long('obs', 'Observaciones adicionales'),
        ]),
        GroupDef(id: 'g_sfv', title: 'Sistema FV existente', questions: [
          _yesNo('existe', '¿Existe sistema FV?', req: true),
          _number('modulos', 'Número de módulos', '', req: true, showIf: sfvYes),
          _text('fabricante', 'Fabricante de módulos', req: true, showIf: sfvYes),
          _text('modelo', 'Modelo de módulos', showIf: sfvYes),
          _number('potencia', 'Potencia instalada', 'kWp', req: true, showIf: sfvYes),
          _number('inversores', 'Número de inversores', '', req: true, showIf: sfvYes),
          _text('interruptores', 'Interruptores: capacidad nominal y de corto circuito', showIf: sfvYes),
          _text('conductores', 'Conductores CD y CA (calibre, material, HxF)', showIf: sfvYes),
          _photo('estructura', 'Estructura de soporte y módulos', Folders.fvExistente, 'FV_ESTRUCTURA',
              req: true, showIf: sfvYes),
          _photo('placas', 'Inversores y placas de datos', Folders.fvExistente, 'FV_PLACAS',
              req: true, showIf: sfvYes),
          _photo('canalizacion', 'Canalización y conductores CD / CA', Folders.fvExistente, 'FV_CANALIZACION',
              showIf: sfvYes),
        ]),
      ]),

      // ------------------------------------------------------------------ 5
      SectionDef(id: 's_generales', title: 'Fotos, videos y documentos', icon: 'camera', groups: [
        GroupDef(id: 'g_evidencia', title: 'Evidencia general', questions: [
          _photo('panoramicas', 'Panorámicas generales de las instalaciones', Folders.generales, 'PANORAMICA',
              req: true, min: 2, hint: 'Dan contexto del inmueble y del ambiente donde se instalará el SFV.'),
          QuestionDef(
            id: 'recorrido',
            label: 'Recorrido general narrado',
            type: QType.video,
            required: true,
            folder: Folders.videos,
            prefix: 'RECORRIDO_GENERAL',
            hint: 'Inicia en la interconexión / M.T. y avanza al interior. Explica en voz alta la '
                'trayectoria del cableado, las alimentaciones y dónde irían inversores y tableros FV.',
          ),
          QuestionDef(
            id: 'dron_video',
            label: 'Vuelo de dron 360° y toma cenital',
            type: QType.video,
            folder: Folders.videos,
            prefix: 'VUELO_DRON',
            hint: 'Importa el video del dron.',
          ),
        ]),
        GroupDef(id: 'g_documentos', title: 'Documentación existente', questions: [
          _doc('ingenieria', 'Ingeniería existente (memorias, expedientes)', Folders.documentacion,
              'INGENIERIA_EXISTENTE',
              cat: 'ingenieria'),
          _doc('planos', 'Planos previos (arquitectónicos, estructurales, eléctricos)', Folders.documentacion,
              'PLANOS',
              cat: 'planos'),
          _doc('cad', 'Archivos CAD y modelos 3D', Folders.cad, 'CAD', cat: 'cad'),
        ]),
      ]),

      // ------------------------------------------------------------------ 6
      SectionDef(id: 's_cierre', title: 'Cierre', icon: 'flag', groups: [
        GroupDef(id: 'g_cierre', title: 'Cierre de levantamiento', questions: [
          _text('guia', 'Nombre de quien guió el recorrido por parte del cliente', req: true),
          _yesNo('dron', '¿Se hizo el vuelo de dron?', req: true),
          _yesNo('punto_caliente', '¿Se detectó una anomalía termográfica grave?', req: true),
          _long('punto_caliente_desc', 'Describe el punto caliente (interruptor, cable, empalme)',
              req: true, showIf: const ShowIf(questionId: 'punto_caliente', equals: yes)),
          _photo('punto_caliente_foto', 'Evidencia del punto caliente', Folders.adicionales, 'PUNTO_CALIENTE',
              showIf: const ShowIf(questionId: 'punto_caliente', equals: yes)),
          _long('conclusiones', 'Observaciones generales y conclusiones'),
          QuestionDef(
            id: 'firma',
            label: 'Firma de quien realizó la visita',
            type: QType.signature,
            required: true,
            folder: Folders.reporte,
            prefix: 'FIRMA_TECNICO',
          ),
        ]),
      ]),
    ],
  );
}

QuestionDef _text(String id, String label, {bool req = false, String hint = '', ShowIf? showIf}) =>
    QuestionDef(id: id, label: label, type: QType.text, required: req, hint: hint, showIf: showIf);

QuestionDef _long(String id, String label, {bool req = false, ShowIf? showIf}) =>
    QuestionDef(id: id, label: label, type: QType.longText, required: req, showIf: showIf);

QuestionDef _number(String id, String label, String unit, {bool req = false, ShowIf? showIf}) =>
    QuestionDef(id: id, label: label, type: QType.number, unit: unit, required: req, showIf: showIf);

QuestionDef _yesNo(String id, String label, {bool req = false}) =>
    QuestionDef(id: id, label: label, type: QType.yesNo, required: req);

QuestionDef _single(String id, String label, List<String> options, {bool req = false}) =>
    QuestionDef(id: id, label: label, type: QType.single, options: options, required: req);

QuestionDef _multi(String id, String label, List<String> options, {bool req = false}) =>
    QuestionDef(id: id, label: label, type: QType.multi, options: options, required: req);

QuestionDef _scale(String id, String label, String unit) =>
    QuestionDef(id: id, label: label, type: QType.scale, unit: unit, min: 0, max: 5);

QuestionDef _photo(String id, String label, String folder, String prefix,
        {bool req = false, int min = 1, String hint = '', ShowIf? showIf}) =>
    QuestionDef(
      id: id,
      label: label,
      type: QType.photo,
      required: req,
      minCount: min,
      folder: folder,
      prefix: prefix,
      hint: hint,
      showIf: showIf,
    );

QuestionDef _doc(String id, String label, String folder, String prefix,
        {bool req = false, String cat = '', String hint = '', ShowIf? showIf}) =>
    QuestionDef(
      id: id,
      label: label,
      type: QType.document,
      required: req,
      folder: folder,
      prefix: prefix,
      docCategory: cat,
      hint: hint,
      showIf: showIf,
    );
