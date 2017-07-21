#!/usr/bin/env python

#import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import mpl_toolkits.mplot3d.axes3d as p3
import matplotlib.animation as animation
import matplotlib.patches as mpatches
#import math
#import rospy
#import os
#import re
import tf#.transformations import euler_from_quaternion as efq
#from tf#.transformations import quaternion_from_euler as qfe
from mobility_games.utils.helper_functions import convert_pose_inverse_transform, convert_translation_rotation_to_pose, invert_transform_2

class G2O_Viz:
    def __init__(self):
        self.vertices = {}
        self.old_vertices = {}
        self.old_edges = {}
        self.new_edges = {}
        self.transdifference = []
        self.rotdifference = []
        self.g2o_result_path = '/home/juicyslew/catkin_ws/result.g2o'
        self.g2o_data_path = '/home/juicyslew/catkin_ws/data_cp.g2o'
    def GatherData(self):
        self.vertices = {}
        self.old_edges = {}
        self.old_vertices = {}
        with open(self.g2o_result_path, 'rb') as g2o_result:
            for line in g2o_result:
                if line.startswith("VERTEX_SE3:QUAT "):
                    line = line.strip()
                    line = line.split(' ')
                    line = [float(i) for i in line[1:]]
                    if line[0] >= 587:
                        self.vertices[int(line[0])] = (tuple(line[1:4]), tuple(line[4:8]))
                        print("found vertex: " + str(line[0]))
                elif line.startswith("EDGE_SE3:QUAT "):
                    line = line.strip()
                    line = line.split(' ')
                    line = [float(i) for i in line[1:]]
                    if int(line[0]) + 1 == int(line[1]):
                        self.old_edges[int(line[0])] = (tuple(line[2:5]), tuple(line[5:9]))
                        print("found edge: " + str(line[0]))
        with open(self.g2o_data_path, 'rb') as g2o_data:
            for line in g2o_data:
                if line.startswith("VERTEX_SE3:QUAT "):
                    line = line.strip()
                    line = line.split(' ')
                    line = [float(i) for i in line[1:]]
                    if line[0] >= 587:
                        self.old_vertices[int(line[0])] = (tuple(line[1:4]), tuple(line[4:8]))
                        print("found vertex: " + str(line[0]))
    def CalculateNewEdges(self):
        self.new_edges = {}
        ind = 587
        i = 0
        #print(self.vertices.keys())
        while i < len(self.old_edges.keys()):
            pose = convert_translation_rotation_to_pose(self.vertices[ind][0], self.vertices[ind][1])
            #print(self.vertices[ind][1])
            #print pose
            (trans, rot) = convert_pose_inverse_transform(pose)
            (trans2, rot2) = self.vertices[ind+1]
            #print(rot)

            T0_1 = tf.transformations.quaternion_matrix(rot)
            T0_1[:-1, -1] = np.asarray(trans).T

            T2_0 = tf.transformations.quaternion_matrix(rot2)
            T2_0[:-1, -1] = np.asarray(trans2)
            #print T2_0
            #print T0_1

            FinTransform = np.matmul(T0_1, T2_0)
            #print FinTransform

            rot_fin = tuple(tf.transformations.quaternion_from_matrix(FinTransform))
            trans_fin = tuple(tf.transformations.translation_from_matrix(FinTransform))
            self.new_edges[ind] = (trans_fin, rot_fin)
            #print("comparison: %s" % ind)
            #print(rot_fin)
            #print(self.old_edges[ind][1])

            ind += 1
            i += 1
    def Calculate_Old_Vertices(self):
        # TODO make function for finding the old vertex locations based on the old edges.
        """ind = 587
        i = 0
        #print(self.vertices.keys())
        fixpoint = self.vertices[0]
        while i < len(self.old_edges.keys()):
            pose = convert_translation_rotation_to_pose(self.old_edges[ind], self.vertices[ind])
            #print(self.vertices[ind][1])
            #print pose
            (trans, rot) = convert_pose_inverse_transform(pose)
            (trans2, rot2) = self.vertices[ind+1]
            #print(rot)

            T0_1 = tf.transformations.quaternion_matrix(rot)
            T0_1[:-1, -1] = np.asarray(trans).T

            T2_0 = tf.transformations.quaternion_matrix(rot2)
            T2_0[:-1, -1] = np.asarray(trans2)
            #print T2_0
            #print T0_1

            FinTransform = np.matmul(T0_1, T2_0)
            #print FinTransform

            rot_fin = tuple(tf.transformations.quaternion_from_matrix(FinTransform))
            trans_fin = tuple(tf.transformations.translation_from_matrix(FinTransform))
            self.new_edges[ind] = (trans_fin, rot_fin)
            #print("comparison: %s" % ind)
            #print(rot_fin)
            #print(self.old_edges[ind][1])

            ind += 1
            i += 1
        pass"""

    """def CalculateDifference(self):
        ind = 587
        i = 0
        #len(self.old_edges.keys())
        self.transdifference = []
        self.rotdifference = []
        while i < len(self.old_edges.keys()):
            transdiff = [self.new_edges[ind][0][j] - self.old_edges[ind][0][j] for j in range(3)]
            #print(transdiff)
            euler_rot0 = tf.transformations.euler_from_quaternion(self.old_edges[ind][1])
            euler_rot1 = tf.transformations.euler_from_quaternion(self.new_edges[ind][1])
            rotdiff = euler_rot1[2] - euler_rot0[2]

            self.transdifference.append(np.linalg.norm(np.asarray(transdiff)))
            self.rotdifference.append(rotdiff)
            ind += 1
            i += 1"""
    def run(self):
        self.GatherData()
        #self.CalculateNewEdges()
        ordered_vertices = []
        old_ordered_vertices = []

        for key in sorted(self.vertices):
            ordered_vertices.append(self.vertices[key][0])
            old_ordered_vertices.append(self.old_vertices[key][0])
        traj_data = np.asarray(ordered_vertices)
        old_traj_data = np.asarray(old_ordered_vertices)
        #self.CalculateDifference()
        #print("final info: ")
        #print("translations: %s" % str(self.transdifference))
        #print("rotations: %s" % str(self.rotdifference))
        # Two subplots, the axes array is 1-d
        #f, axarr = plt.subplots(, sharex=True)
        #axarr[0].plot(x, y)
        #axarr[0].set_title('Sharing X axis')
        #axarr[1].scatter(x, y)
        fig = plt.figure()
        ax = p3.Axes3D(fig)
        new_path, = plt.plot(traj_data[:,0], traj_data[:,1], traj_data[:,2], label = 'corrected trajectory')
        old_path, = plt.plot(old_traj_data[:,0], old_traj_data[:,1], old_traj_data[:,2], label = 'original trajectory')
        plt.legend(handles = [new_path, old_path])
        plt.xlabel('X')
        plt.ylabel('Y')
        #plt.zlabel('Z')
        plt.title('G2O Trajectory Plot')
        plt.grid(True)

        plt.show()

if __name__ == "__main__":
    g2o_viz = G2O_Viz()
    g2o_viz.run()