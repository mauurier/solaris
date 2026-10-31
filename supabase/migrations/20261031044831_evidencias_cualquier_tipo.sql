-- Las evidencias de tipo documento son archivos nativos (termografías .is2,
-- DWG, hojas de cálculo...), no sólo fotos, videos y PDF. El límite de
-- 50 MB por archivo se queda.
update storage.buckets set allowed_mime_types = null where id = 'evidencias';
