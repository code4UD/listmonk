<template>
  <div class="mairies-map">
    <div id="map" ref="mapContainer" :style="{ height: mapHeight }" />
  </div>
</template>

<script>
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import 'leaflet.markercluster/dist/MarkerCluster.Default.css';
import 'leaflet.markercluster';

// Fix for default markers in Leaflet with webpack
// eslint-disable-next-line no-underscore-dangle
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  // eslint-disable-next-line global-require
  iconRetinaUrl: require('leaflet/dist/images/marker-icon-2x.png'),
  // eslint-disable-next-line global-require
  iconUrl: require('leaflet/dist/images/marker-icon.png'),
  // eslint-disable-next-line global-require
  shadowUrl: require('leaflet/dist/images/marker-shadow.png'),
});

export default {
  name: 'MairiesMap',
  props: {
    mairies: {
      type: Array,
      default: () => [],
    },
    height: {
      type: String,
      default: '400px',
    },
    center: {
      type: Array,
      default: () => [46.603354, 1.888334], // Centre de la France
    },
    zoom: {
      type: Number,
      default: 6,
    },
    showClusters: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      map: null,
      markers: [],
      markerClusterGroup: null,
    };
  },
  computed: {
    mapHeight() {
      return this.height;
    },
  },
  mounted() {
    this.initMap();
    this.updateMarkers();
  },
  watch: {
    mairies: {
      handler() {
        this.updateMarkers();
      },
      deep: true,
    },
  },
  beforeDestroy() {
    if (this.map) {
      this.map.remove();
    }
  },
  methods: {
    initMap() {
      // Initialiser la carte
      this.map = L.map(this.$refs.mapContainer).setView(this.center, this.zoom);

      // Ajouter les tuiles OpenStreetMap
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      }).addTo(this.map);

      // Initialiser le groupe de clusters si activé
      if (this.showClusters && window.L && window.L.markerClusterGroup) {
        this.markerClusterGroup = L.markerClusterGroup({
          chunkedLoading: true,
          maxClusterRadius: 50,
        });
        this.map.addLayer(this.markerClusterGroup);
      }
    },

    updateMarkers() {
      if (!this.map) return;

      // Supprimer les anciens marqueurs
      this.clearMarkers();

      // Ajouter les nouveaux marqueurs
      this.mairies.forEach((mairie) => {
        if (mairie.latitude && mairie.longitude) {
          this.addMarker(mairie);
        }
      });

      // Ajuster la vue si il y a des marqueurs
      if (this.markers.length > 0) {
        this.fitBounds();
      }
    },

    addMarker(mairie) {
      const marker = L.marker([mairie.latitude, mairie.longitude]);

      // Créer le popup avec les informations de la mairie
      const popupContent = `
        <div class="mairie-popup">
          <h4>${mairie.nom_commune}</h4>
          <p><strong>Département:</strong> ${mairie.code_departement}</p>
          <p><strong>Population:</strong> ${mairie.population?.toLocaleString() || 'N/A'}</p>
          <p><strong>Code INSEE:</strong> ${mairie.code_insee}</p>
          ${mairie.email ? `<p><strong>Email:</strong> <a href="mailto:${mairie.email}">${mairie.email}</a></p>` : ''}
          ${mairie.nom_contact ? `<p><strong>Contact:</strong> ${mairie.nom_contact}</p>` : ''}
        </div>
      `;

      marker.bindPopup(popupContent);

      // Ajouter le marqueur au groupe de clusters ou directement à la carte
      if (this.showClusters && this.markerClusterGroup) {
        this.markerClusterGroup.addLayer(marker);
      } else {
        marker.addTo(this.map);
      }

      this.markers.push(marker);

      // Émettre un événement quand on clique sur un marqueur
      marker.on('click', () => {
        this.$emit('marker-click', mairie);
      });
    },

    clearMarkers() {
      if (this.showClusters && this.markerClusterGroup) {
        this.markerClusterGroup.clearLayers();
      } else {
        this.markers.forEach((marker) => {
          this.map.removeLayer(marker);
        });
      }
      this.markers = [];
    },

    fitBounds() {
      if (this.markers.length === 0) return;

      if (this.showClusters && this.markerClusterGroup) {
        this.map.fitBounds(this.markerClusterGroup.getBounds(), { padding: [20, 20] });
      } else {
        // eslint-disable-next-line new-cap
        const group = new L.featureGroup(this.markers);
        this.map.fitBounds(group.getBounds(), { padding: [20, 20] });
      }
    },

    // Méthodes publiques pour contrôler la carte
    setView(center, zoom) {
      if (this.map) {
        this.map.setView(center, zoom);
      }
    },

    addDepartmentBounds(departmentCode) {
      // Ici on pourrait ajouter les contours des départements
      // Pour l'instant, on centre sur les mairies du département
      const deptMairies = this.mairies.filter((m) => m.code_departement === departmentCode);
      if (deptMairies.length > 0) {
        const bounds = L.latLngBounds(deptMairies.map((m) => [m.latitude, m.longitude]));
        this.map.fitBounds(bounds, { padding: [20, 20] });
      }
    },

    highlightMarker(mairieId) {
      // Mettre en évidence un marqueur spécifique
      const mairie = this.mairies.find((m) => m.id === mairieId);
      if (mairie && mairie.latitude && mairie.longitude) {
        this.map.setView([mairie.latitude, mairie.longitude], 12);

        // Ouvrir le popup du marqueur correspondant
        const marker = this.markers.find((m) => {
          const pos = m.getLatLng();
          return pos.lat === mairie.latitude && pos.lng === mairie.longitude;
        });
        if (marker) {
          marker.openPopup();
        }
      }
    },
  },
};
</script>

<style scoped>
.mairies-map {
  width: 100%;
  border-radius: 4px;
  overflow: hidden;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

#map {
  width: 100%;
}

/* Styles pour les popups */
:deep(.mairie-popup) {
  min-width: 200px;
}

:deep(.mairie-popup h4) {
  margin: 0 0 10px 0;
  color: #333;
  font-size: 16px;
}

:deep(.mairie-popup p) {
  margin: 5px 0;
  font-size: 14px;
  line-height: 1.4;
}

:deep(.mairie-popup a) {
  color: #007cba;
  text-decoration: none;
}

:deep(.mairie-popup a:hover) {
  text-decoration: underline;
}

/* Styles pour les clusters */
:deep(.marker-cluster-small) {
  background-color: rgba(181, 226, 140, 0.6);
}

:deep(.marker-cluster-small div) {
  background-color: rgba(110, 204, 57, 0.6);
}

:deep(.marker-cluster-medium) {
  background-color: rgba(241, 211, 87, 0.6);
}

:deep(.marker-cluster-medium div) {
  background-color: rgba(240, 194, 12, 0.6);
}

:deep(.marker-cluster-large) {
  background-color: rgba(253, 156, 115, 0.6);
}

:deep(.marker-cluster-large div) {
  background-color: rgba(241, 128, 23, 0.6);
}
</style>
