const express = require('express');
const cors = require('cors');
const { createCanvas, loadImage } = require('canvas');
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// CONFIGURACIÓN DE NEON
// Reemplaza esto con tu URL real de Neon
const neonUrl = 'postgres://USUARIO:CONTRASEÑA@ep-lively-cell-ayitmvym.apirest.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require';
const pool = new Pool({ connectionString: neonUrl });

function p3(n){ return Math.round(n*1000)/1000; }

app.post('/process', async (req, res) => {
    try {
        const { image, resolution, pSize, thickness, merge } = req.body;
        
        // Decodificar la imagen Base64
        const buffer = Buffer.from(image, 'base64');
        const img = await loadImage(buffer);
        
        // Escalar manteniendo la proporción exacta
        const scale = resolution / Math.max(img.width, img.height);
        const activeW = Math.max(1, Math.floor(img.width * scale));
        const activeH = Math.max(1, Math.floor(img.height * scale));
        
        // Usar Canvas para extraer los píxeles
        const canvas = createCanvas(activeW, activeH);
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, activeW, activeH);
        const px = ctx.getImageData(0, 0, activeW, activeH).data;
        
        const blocksArr = [];
        const startX = -(activeW * pSize) / 2;
        const startY = 0;
        
        const grid = [];
        for (let y = 0; y < activeH; y++) {
            grid[y] = [];
            for (let x = 0; x < activeW; x++) {
                const i = (y * activeW + x) * 4;
                const r = px[i] / 255;
                const g = px[i + 1] / 255;
                const b = px[i + 2] / 255;
                const a = px[i + 3] / 255;
                grid[y][x] = (a > 0.05) ? {r, g, b, a} : null;
            }
        }
        
        // Generar bloques (con o sin fusión)
        if (!merge) {
            for (let y = 0; y < activeH; y++) {
                for (let x = 0; x < activeW; x++) {
                    const cell = grid[y][x];
                    if (!cell) continue;
                    const relX = p3(startX + x * pSize + pSize/2);
                    const relY = p3(startY + (activeH - 1 - y) * pSize + pSize/2);
                    blocksArr.push({ x: relX, y: relY, z: 0, sx: pSize, sy: pSize, sz: thickness, r: cell.r, g: cell.g, b: cell.b });
                }
            }
        } else {
            const used = [];
            for (let y = 0; y < activeH; y++) used[y] = new Array(activeW).fill(false);
            
            for (let y = 0; y < activeH; y++) {
                for (let x = 0; x < activeW; x++) {
                    const cell = grid[y][x];
                    if (!cell || used[y][x]) continue;
                    const key = `${cell.r},${cell.g},${cell.b}`;
                    let w = 1;
                    while (x + w < activeW && !used[y][x+w] && grid[y][x+w] && `${grid[y][x+w].r},${grid[y][x+w].g},${grid[y][x+w].b}` === key) w++;
                    let h = 1; let canGrow = true;
                    while (canGrow && y + h < activeH) {
                        for (let k = x; k < x + w; k++) {
                            const below = grid[y+h][k];
                            if (!below || used[y+h][k] || `${below.r},${below.g},${below.b}` !== key) { canGrow = false; break; }
                        }
                        if (canGrow) h++;
                    }
                    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) used[yy][xx] = true;
                    
                    const centerX = p3(startX + x * pSize + (w * pSize)/2);
                    const centerY = p3(startY + (activeH - 1 - y) * pSize + (h * pSize)/2);
                    blocksArr.push({ x: centerX, y: centerY, z: 0, sx: pSize * w, sy: pSize * h, sz: thickness, r: cell.r, g: cell.g, b: cell.b });
                }
            }
        }
        
        // Guardar en Neon
        const id = uuidv4();
        await pool.query('INSERT INTO image_builds (id, blocks, count) VALUES ($1, $2, $3)', [id, JSON.stringify(blocksArr), blocksArr.length]);
        
        res.json({ success: true, id: id, count: blocksArr.length, blocks: blocksArr });
    } catch (e) {
        console.error(e);
        res.status(500).json({ success: false, error: e.message });
    }
});

app.listen(3000, () => console.log('Server running on port 3000'));
