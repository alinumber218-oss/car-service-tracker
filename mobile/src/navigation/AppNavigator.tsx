import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import LoginScreen from '../screens/LoginScreen';
import VehicleListScreen from '../screens/VehicleListScreen';

export type RootStackParamList = {
  Login: undefined;
  VehicleList: undefined;
  VehicleDetail: { vehicleId: string };
  AddVehicle: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function AppNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Login">
        <Stack.Screen name="Login" component={LoginScreen} options={{ headerShown: false }} />
        <Stack.Screen
          name="VehicleList"
          component={VehicleListScreen}
          options={{ title: 'My Vehicles' }}
        />
        {/* VehicleDetail and AddVehicle screens are next up - see docs/ROADMAP.md */}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
