const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus server URL
const PROMETHEUS_URL = process.env.PROMETHEUS_URL || 'http://prometheus.monitoring.svc.cluster.local:9090';

// Serve static HTML
app.use(express.static(__dirname));

// Helper function to query Prometheus
async function queryPrometheus(query) {
    try {
        const url = `${PROMETHEUS_URL}/api/v1/query?query=${encodeURIComponent(query)}`;
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Prometheus query failed: ${response.statusText}`);
        }
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Prometheus query error:', error.message);
        return null;
    }
}

// Helper function to query Prometheus range
async function queryPrometheusRange(query, start, end, step = '1h') {
    try {
        const url = `${PROMETHEUS_URL}/api/v1/query_range?query=${encodeURIComponent(query)}&start=${start}&end=${end}&step=${step}`;
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Prometheus range query failed: ${response.statusText}`);
        }
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Prometheus range query error:', error.message);
        return null;
    }
}

// API endpoint to check core-pipeline-prod
app.get('/api/check/core-pipeline-prod', async (req, res) => {
    const result = await queryPrometheus('up{job="core-pipeline-prod"}');

    if (result && result.status === 'success' && result.data.result.length > 0) {
        const value = parseFloat(result.data.result[0].value[1]);
        res.json({
            status: value === 1 ? 'up' : 'down',
            responseTime: null
        });
    } else {
        res.json({ status: 'down', responseTime: null });
    }
});

// API endpoint to check core-pipeline-dev
app.get('/api/check/core-pipeline-dev', async (req, res) => {
    const result = await queryPrometheus('up{job="core-pipeline-dev"}');

    if (result && result.status === 'success' && result.data.result.length > 0) {
        const value = parseFloat(result.data.result[0].value[1]);
        res.json({
            status: value === 1 ? 'up' : 'down',
            responseTime: null
        });
    } else {
        res.json({ status: 'down', responseTime: null });
    }
});

// API endpoint to check PostgreSQL
app.get('/api/check/postgresql', async (req, res) => {
    const result = await queryPrometheus('up{job="postgresql"}');

    if (result && result.status === 'success' && result.data.result.length > 0) {
        const value = parseFloat(result.data.result[0].value[1]);
        res.json({
            status: value === 1 ? 'up' : 'down',
            responseTime: null
        });
    } else {
        res.json({ status: 'down', responseTime: null });
    }
});

// API endpoint to check Redis
app.get('/api/check/redis', async (req, res) => {
    const result = await queryPrometheus('up{job="redis"}');

    if (result && result.status === 'success' && result.data.result.length > 0) {
        const value = parseFloat(result.data.result[0].value[1]);
        res.json({
            status: value === 1 ? 'up' : 'down',
            responseTime: null
        });
    } else {
        res.json({ status: 'down', responseTime: null });
    }
});

// API endpoint to check Kafka
app.get('/api/check/kafka', async (req, res) => {
    const result = await queryPrometheus('up{job="kafka"}');

    if (result && result.status === 'success' && result.data.result.length > 0) {
        const value = parseFloat(result.data.result[0].value[1]);
        res.json({
            status: value === 1 ? 'up' : 'down',
            responseTime: null
        });
    } else {
        res.json({ status: 'down', responseTime: null });
    }
});

// API endpoint to check Hetzner (use node exporter if available, or ping)
app.get('/api/check/hetzner', async (req, res) => {
    // For now, assume up since we're running on it
    res.json({ status: 'up', responseTime: null });
});

// API endpoint to get uptime history for a service
app.get('/api/uptime/:service', async (req, res) => {
    const { service } = req.params;
    const days = parseInt(req.query.days) || 90;

    // Map service names to Prometheus job labels
    const jobMap = {
        'core-pipeline-prod': 'core-pipeline-prod',
        'core-pipeline-dev': 'core-pipeline-dev',
        'postgresql': 'postgresql',
        'redis': 'redis',
        'kafka': 'kafka'
    };

    const job = jobMap[service];
    if (!job) {
        return res.status(404).json({ error: 'Service not found' });
    }

    const end = Math.floor(Date.now() / 1000);
    const start = end - (days * 24 * 60 * 60);

    // Query uptime over the period
    const result = await queryPrometheusRange(
        `avg_over_time(up{job="${job}"}[1h])`,
        start,
        end,
        '1h'
    );

    if (result && result.status === 'success' && result.data.result.length > 0) {
        const values = result.data.result[0].values.map(([timestamp, value]) => ({
            timestamp: timestamp * 1000,
            uptime: parseFloat(value) * 100
        }));

        // Group by day
        const dailyUptime = {};
        values.forEach(({ timestamp, uptime }) => {
            const date = new Date(timestamp).toISOString().split('T')[0];
            if (!dailyUptime[date]) {
                dailyUptime[date] = [];
            }
            dailyUptime[date].push(uptime);
        });

        const history = Object.entries(dailyUptime).map(([date, uptimes]) => {
            const avgUptime = uptimes.reduce((sum, val) => sum + val, 0) / uptimes.length;
            return {
                date,
                uptime: avgUptime.toFixed(2),
                status: avgUptime > 99 ? 'up' : avgUptime > 0 ? 'degraded' : 'down'
            };
        });

        res.json({ history });
    } else {
        res.json({ history: [] });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'status-page' });
});

// Serve index.html for root
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Status page server running on port ${PORT}`);
    console.log(`Prometheus URL: ${PROMETHEUS_URL}`);
});
